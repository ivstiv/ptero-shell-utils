#!/bin/sh

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

# accepts parameter as starting page
getAllServers() {
    [ -z "$1" ] && page="1" || page="$1"

    data=$(curl -s "$PANEL_FQDN/api/application/servers?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq '.data[] | .attributes.uuid' --raw-output
    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getAllServers "$nextPage"
}

# accepts node ID and starting page
getServersByNodeID() {
    [ -z "$1" ] && echo "Error: Please specify node ID" >&2 && return
    [ -z "$2" ] && page="1" || page="$2"

    data=$(curl -s "$PANEL_FQDN/api/application/servers?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq ".data[] | select(.attributes.node == $1) | .attributes.uuid" --raw-output
    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getServersByNodeID "$1" "$nextPage"
}

# accepts userID and starting page
getServersByUserID() {
    [ -z "$1" ] && echo "Error: Please specify user id" >&2 && return
    [ -z "$2" ] && page="1" || page="$2"

    data=$(curl -s "$PANEL_FQDN/api/application/servers?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq ".data[] | select(.attributes.user == $1) | .attributes.uuid" --raw-output
    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getServersByUserID "$1" "$nextPage"
}

# accepts username
# the function assumes that the username is validated with isUsernameValid() !!!
getServersByUsername() {
    [ -z "$1" ] && echo "Error: Please specify username" >&2 && return
    # find the corresponding id to search for servers 
    userID=$(usernameToUserID "$1")
    getServersByUserID "$userID" 
}

# accepts parameter as starting page
getAllNodes() {
    [ -z "$1" ] && page="1" || page="$1"

    data=$(curl -s "$PANEL_FQDN/api/application/nodes?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq '.data[] | [.attributes.id, .attributes.name ] | @csv' --raw-output | \
    awk -v FS="," 'BEGIN{print "ID\tName";print "================="}{printf "%s\t%s%s",$1,$2,ORS}'

    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getAllNodes "$nextPage"
}

# accepts parameter as starting page

getAllUsers() {
    [ -z "$1" ] && page="1" || page="$1"

    data=$(curl -s "$PANEL_FQDN/api/application/users?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    echo "$data" | jq '.data[] | .attributes.username' --raw-output
    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && getAllUsers "$nextPage"
}

#accepts server-uuid and action
executeAction() {
    # if the user inputs the UUID we need only the first 8 characters
    if [ "${#1}" -gt 8 ]; then
        server_id=$(echo "$1" | cut -c 1-8)
    else
        server_id="$1"
    fi

    if [ "$mock" = "y" ]; then
        echo "Sending mock action \"$2\" to server $1..."
        return
    else
        echo "Sending action \"$2\" to server $1..."
    fi
    
    curl -s "$PANEL_FQDN/api/client/servers/$server_id/power" \
            -H "Authorization: Bearer $CLIENT_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X POST \
            -d "{ \"signal\": \"$2\" }"
}

# accepts username and starting page
usernameToUserID() {
    [ -z "$1" ] && echo "Error: Please specify username" >&2 && return
    [ -z "$2" ] && page="1" || page="$2"

    data=$(curl -s "$PANEL_FQDN/api/application/users?page=$page" \
            -H "Authorization: Bearer $APP_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X GET)

    id=$(echo "$data" | jq ".data[] | select(.attributes.username == \"$1\") | .attributes.id" --raw-output)
    [ -n "$id" ] && echo "$id" && return
    # get the next page if it exists
    nextPage=$(echo "$data" | jq '.meta.pagination | select(.current_page != .total_pages) | .links.next | split("=") | last' --raw-output)

    # recursive call
    [ -n "$nextPage" ] && usernameToUserID "$1" "$nextPage"
}

# accepts server_uuid
isServerIDValid() {
    # because searching for server info is done with internal id we will loop over all uuid..
    # ugly but more user friendly..
    [ -z "$1" ] && echo "Error: Please specify server UUID" >&2 && return
    [ "${#1}" -lt 8 ] && echo "Error: Invalid format of server UUID" >&2 && return
    server_uuids=$(getAllServers)
    echo "$server_uuids" | grep -c "$1"
}

# accepts node ID
isNodeIDValid() {
    [ -z "$1" ] && echo "Error: Please specify Node ID" >&2 && return
    nodes=$(getAllNodes)
    echo "$nodes" | awk '{print $1}' | grep -cE "(^|\s)$1($|\s)"
}

# accepts username
isUsernameValid() {
    [ -z "$1" ] && echo "Error: Please specify username" >&2 && return
    users=$(getAllUsers)
    echo "$users" | grep -cE "(^|\s)$1($|\s)"
}

# accepts action string
isActionValid() {
    printf "start\nstop\nrestart\nkill" | grep -cE "(^|\s)$1($|\s)"
}

checkDependencies() {
    mainShellPID="$$"
    printf "jq\ngrep\nawk\ncurl" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}


######################
# VALIDATE ARGUMENTS #
######################

checkDependencies

# set defaults 
server='' user='' node='' action='' force='n' mock="n"
uniqueArguments=0

# loop over the arguments
# leaving this here just in case https://stackoverflow.com/questions/34434157/posix-sh-syntax-for-for-loops-sc2039
while [ -n "$1" ]; do

    if [ "$1" = "--server" ]; then 
        uniqueArguments=$((uniqueArguments+1))
        shift 
        # this actually works with both with full UUID and the first 8 chars of it
        if [ "$1" = "all" ]; then
            server="all"
        elif [ "$(isServerIDValid "$1")" -eq 1 ]; then
            server="$1"
        else
            echo "Error: Invalid server UUID $1" >&2 && exit
        fi

    elif [ "$1" = "--user" ]; then
        uniqueArguments=$((uniqueArguments+1))
        shift
        if [ "$(isUsernameValid "$1")" -eq 1 ]; then
            user="$1"
        else
            echo "Error: Invalid username $1" >&2 && exit
        fi

    elif [ "$1" = "--node" ]; then
        uniqueArguments=$((uniqueArguments+1))
        # if the user doesn't know the node ids let him choose
        if case "$2" in "--"*) true;; *) false;; esac; then
            getAllNodes
            printf "Please choose Node ID >>"
            read -r nodeID
            if [ "$(isNodeIDValid "$nodeID")" -eq 1 ]; then
            node="$nodeID"
            else
                echo "Error: Invalid node ID $nodeID" >&2 && exit
            fi
        # if he knows the id just validate it
        else
            shift
            if [ "$(isNodeIDValid "$1")" -eq 1 ]; then
            node="$1"
            else
                echo "Error: Invalid node ID $1" >&2 && exit
            fi
        fi

    elif [ "$1" = "--action" ]; then
        shift
        if [ "$(isActionValid "$1")" -eq 1 ]; then
            action="$1"
        else 
            echo "Error: Invalid action $1" >&2 && exit
        fi

    elif [ "$1" = "--force" ]; then
        force=y

    elif [ "$1" = "--mock" ]; then
        mock=y
    else 
        echo "Invalid argument: $1" && exit
    fi
    shift
done

[ "$uniqueArguments" -eq 0 ] && echo "Error: You need to choose either --server, --user or --node but not together!" >&2 && exit
[ "$uniqueArguments" -gt 1 ] && echo "Error: You need to choose either --server, --user or --node but not together!" >&2 && exit
[ -z "$action" ] && echo "Error: You must specify an action." >&2 && exit

####################
# HANDLE THE QUERY #
####################

echo "THE FOLLOWING ACTION WILL BE EXECUTED:"
[ -n "$server" ] && echo "  - Server: $server"
[ -n "$user" ] && echo "  - All servers of user: $user"
[ -n "$node" ] && echo "  - All servers on node: $node"
echo "  - Action: $action"
[ "$mock" = "y" ] && echo "  - WARNING: You are running in mock mode which means that no actions will be actually executed! ! !"

if [ "$force" = "n" ]; then
    while true; do
        echo "Are you sure you want to continue with this action? (yes/no)"
        read -r yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Stopping..." && exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

echo "Executing..."

if [ -n "$server" ]; then
    if [ "$server" = "all" ]; then
        getAllServers | while IFS= read -r server_uuid; do
            executeAction "$server_uuid" "$action"
        done
    else
        executeAction "$server" "$action"
    fi
elif [ -n "$user" ]; then
    getServersByUsername "$user" | while IFS= read -r server_uuid; do
        executeAction "$server_uuid" "$action"
    done
elif [ -n "$node" ]; then
    getServersByNodeID "$node" | while IFS= read -r server_uuid; do
        executeAction "$server_uuid" "$action"
    done
fi

##############
# TEST CASES #
##############

# I am leaving all of this here so that if you want to debug a function
# this would be the expected behaviour of the core functions.

# test action on all servers
#getAllServers | while IFS= read -r server_uuid; do
#    executeAction "$server_uuid" "start"
#done

# testing validity of server uuid
#isServerIDValid # no parameter -> error
#isServerIDValid 7db48acc-9d54-4c0a-925e-8fa9fc90a2c2 # valid uuid -> 1
#isServerIDValid 7db48acc # valid short uuid -> 1
#isServerIDValid 7db48acc-9d54-4c0a-925e-8fa9fc90a2cg # invalid uuid -> 0
#isServerIDValid cc # invalid uuid but containing chars from another uuid -> 0

# testing validity of node id
#isNodeIDValid 32 # valid id -> 1
#isNodeIDValid 2 # valid id containing digit of another id -> 1
#isNodeIDValid 99 # invalid id -> 0  

# test action on servers by node
#getServersByNodeID 2 | while IFS= read -r server_uuid; do
#    executeAction "$server_uuid" "start"
#done

# test validity of username
#isUsernameValid todor2110r2x # valid username -> 1
#isUsernameValid todor # partial name only -> 0
#isUsernameValid # no param -> error

# testing getting servers by username
#getServersByUsername support # valid username -> prints all UUIDs
#getServersByUsername qfkk7bei # invalid username -> prints nothing