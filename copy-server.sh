#!/bin/sh

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

# accepts parameter as starting page
getAllNodes() {
    [ -z "$1" ] && page="1" || page="$1"

    data=$(curl -s "$PANEL_FQDN/api/application/nodes?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq '.data[] | [.attributes.id, .attributes.name ] | @csv' --raw-output | \
    awk -v FS="," '{printf "%s\t%s%s",$1,$2,ORS}'

    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getAllNodes "$nextPage"
}

# accepts node ID, all nodes
isNodeIDValid() {
    [ -z "$1" ] && echo "Error: Please specify Node ID" >&2 && exit
    [ -z "$2" ] && echo "Error: Please specify Node List" >&2 && exit
    echo "$2" | awk '{print $1}' | grep -cE "(^|\s)$1($|\s)"
}

# accepts node ID and optional parameter as starting page
getAllocations() {
    [ -z "$2" ] && page="1" || page="$2"

    data=$(curl -s "$PANEL_FQDN/api/application/nodes/$1/allocations?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq '.data[].attributes | select(.assigned == false)'

    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getAllocations "$1" "$nextPage"
}

# accepts uuid, starting page
getServerByUUID() {
    [ -z "$1" ] && echo "Error: Please specify UUID" >&2 && return
    [ -z "$2" ] && page="1" || page="$2"

    data=$(curl -s "$PANEL_FQDN/api/application/servers?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    serverData=$(echo "$data" | jq ".data[] | select(.attributes.uuid == \"$1\")")

    if [ -z "$serverData" ]; then
        # get the next page if it exists
        nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

        # recursive call
        [ -n "$nextPage" ] && getServerByUUID "$1" "$nextPage"
    else
        echo "$serverData"
    fi
}

# accepts serverUUID as parameter
suspendServer() {
    printf "\nSuspending the old server. . .\n"
    oldServerID=$(getServerByUUID "$1" | jq '.attributes.id')
    curl -s "$PANEL_FQDN/api/application/servers/$oldServerID/suspend" \
        -H "Authorization: Bearer $APP_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X POST 
}

checkDependencies() {
    mainShellPID="$$"
    printf "curl\njq\nawk\ngrep\ncut\nsshpass\nsftp\nssh-keyscan" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

#############
# EXECUTION #
#############

checkDependencies

# Get all local servers on the node 
echo "Searching for servers on this node. . ."
cd "$DAEMON_DATA_DIR" || exit
for d in */; do 
    if [  -d "$d" ]; then
        echo "    - ${d%/}"
    fi
done

serverUUID='somethingthatshouldnotexistinthisdirectory123!@#$%^'
while [ ! -d "$DAEMON_DATA_DIR/$serverUUID" ]; do
    printf "\nSelect a server UUID for the transfer:"
    read -r serverUUID
    # Validate that the selected directory exists
    if [ ! -d "$DAEMON_DATA_DIR/$serverUUID" ]; then
        echo "Error: Invalid server UUID! May be you have copied an empty space along with the UUID." >&2
    fi
done


# Node destination selection
printf "ID\tName\n"
echo "================="
nodeList=$(getAllNodes)
echo "$nodeList"
nodeID=''
while [ -z "$nodeID" ]; do
    printf "Where do you want to copy the server to? (Node ID):"
    read -r nodeID
    if [ "$(isNodeIDValid "$nodeID" "$nodeList")" -eq 0 ]; then
        echo "Error: Invalid node ID $nodeID" >&2
        echo "Retrying. . ."
        nodeID=''
    fi
done

# Get available allocations for the selected node
printf "\nLoading all unassigned allocations from the specified node (this might take a while). . .\n"
allocations=$(getAllocations "$nodeID")

# Select new allocation
allocationId=''
while [ -z "$allocationId" ]; do
    echo "Available IP adresses on the new node:"
    uniqueIps=$(echo "$allocations" | jq -s . | jq 'unique_by(.ip)[] | .ip' --raw-output | awk '{print "    - " $0}')

    if [ -z "$uniqueIps" ]; then
        echo "No unassigned allocations available on this node. Add some from the panel and start again."
        exit
    else
        echo "$uniqueIps"
    fi
    
    printf "\nPlease choose the new ip of the server:"
    read -r newIp
    printf "Please choose the new port of the server:"
    read -r newPort

    allocationId=$(echo "$allocations" | jq "select(.ip == \"$newIp\" and .port == $newPort) | .id")
    # check if the allocation exists
    if [ -z "$allocationId" ]; then 
        echo "Error: Invalid Ip or Port number - $newIp:$newPort" >&2
        echo "Check your panel to see if the port that you need exists on the new node." >&2
        printf "Retrying. . .\n"
    fi
done

echo "The new default allocation of the server will be $newIp:$newPort."
echo "If you would like to add more allocations to the server you will need to do that later from the panel."

# Get information about the server
echo "Obtaining details about the server from the panel. . ."
serverData=$(getServerByUUID "$serverUUID")

echo "Creating the new server. . ."
environment=$(echo "$serverData" | jq '.attributes.container.environment')
body="{
    \"name\": \"$(echo "$serverData" | jq '.attributes.name' --raw-output)\",
    \"user\": $(echo "$serverData" | jq '.attributes.user' --raw-output),
    \"description\": \"$(echo "$serverData" | jq '.attributes.description' --raw-output)\",
    \"egg\": $(echo "$serverData" | jq '.attributes.egg' --raw-output),
    \"pack\": $(echo "$serverData" | jq '.attributes.pack' --raw-output),
    \"docker_image\": \"$(echo "$serverData" | jq '.attributes.container.image' --raw-output)\",
    \"startup\": $(echo "$serverData" | jq '.attributes.container.startup_command'),
    \"limits\": {
        \"memory\": $(echo "$serverData" | jq '.attributes.limits.memory' --raw-output),
        \"swap\": $(echo "$serverData" | jq '.attributes.limits.swap' --raw-output),
        \"disk\": $(echo "$serverData" | jq '.attributes.limits.disk' --raw-output),
        \"io\": $(echo "$serverData" | jq '.attributes.limits.io' --raw-output),
        \"cpu\": $(echo "$serverData" | jq '.attributes.limits.cpu' --raw-output)
    },
    \"feature_limits\": {
        \"databases\": $(echo "$serverData" | jq '.attributes.feature_limits.databases' --raw-output),
        \"allocations\": 1
    },
    \"environment\": $environment,
    \"allocation\": {
      \"default\": $allocationId,
      \"additional\": []
    },
    \"start_on_completion\": false,
    \"skip_scripts\": true,
    \"oom_disabled\": true
  }"

# create the new server 
response=$(curl -s "$PANEL_FQDN/api/application/servers" \
  -H "Authorization: Bearer $APP_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: Application/vnd.pterodactyl.v1+json" \
  -X POST \
  -d "$body")

newServerID=$(echo "$response" | jq '.attributes.id')
newServerUUID=$(echo "$response" | jq '.attributes.uuid' --raw-output)

if [ -z "$newServerUUID" ]; then
    echo "There was a problem with the creation of the server. Most likely a startup parameter or environmental variables has broken the json body of the request."
    echo "Contact me on github, discord etc. with info about the server you are trying to copy to fix it."
    exit
fi

echo "The new server has been created! Waiting for the installation to finish."
isInstalled=false
while [ "$isInstalled" != "true" ]; do
    echo "Checking install status. . ."
    statusResponse=$(curl -s "$PANEL_FQDN/api/application/servers/$newServerID" \
         -H "Authorization: Bearer $APP_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X "GET")

    isInstalled=$(echo "$statusResponse" | jq '.attributes.container.installed' --raw-output)
    sleep 5
done
echo "The installation process has finished."

while true; do
    printf "Do you want to suspend the original server? (yes/no):"
    read -r yn
    case $yn in
        [Yy]* ) suspendServer "$serverUUID" && break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

destinationNodeInfo=$(curl -s "$PANEL_FQDN/api/application/nodes/$nodeID" \
                            -H "Authorization: Bearer $APP_API_KEY" \
                            -H "Content-Type: application/json" \
                            -H "Accept: Application/vnd.pterodactyl.v1+json" \
                            -X GET)
destinationDaemonBase=$(echo "$destinationNodeInfo" | jq '.attributes.daemon_base' --raw-output)

# Final messages
printf "\n\n"
echo "Congratulations! The copy of server $serverUUID was created successfully!"
echo "New server UUID: $newServerUUID"
echo "New server allocation $newIp:$newPort"

printf "\nUnfortunately this script has its limitations and you will need to take care of the following things:\n"
printf "1. Any subusers need to be manually added to the new server.\n"
printf "2. Any additional allocations need to be manually setup from the panel.\n"
printf "3. If the server had any databases, their transfer cannot be facilitated through the pterodactyl's api.\n"
printf "4. Make sure that configuration files in the server reflect its new allocation.\n\n"

echo "If you also want to transfer the files of the server here are a few useful commands:"
echo "Archive the original server via:"
echo "cd $DAEMON_DATA_DIR/$serverUUID && tar -czvf $serverUUID.tar.gz *"
echo "Then move the archive to the new node and extract it via:"
echo "tar -xvzf $serverUUID.tar.gz -C $destinationDaemonBase/$newServerUUID"
echo "Or if both servers are on the same node you can just copy the files over:"
echo "cp -R $DAEMON_DATA_DIR/$serverUUID/. $DAEMON_DATA_DIR/$newServerUUID"
