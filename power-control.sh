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

#accepts server-uuid and action
executeAction() {
    # if the user inputs the UUID we need only the first 8 characters
    if [ "${#1}" -gt 8 ]; then
        server_id=$(echo "$1" | cut -c 1-8)
    else
        server_id="$1"
    fi

    echo "Sending action \"$2\" to server $1..."
    # REMOVE THIS AFTER TESTING
    return

    curl -s "$PANEL_FQDN/api/client/servers/$server_id/power" \
            -H "Authorization: Bearer $CLIENT_API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: Application/vnd.pterodactyl.v1+json" \
            -X POST \
            -d "{ \"signal\": \"$2\" }"
}

# accepts server_uuid
isServerIDValid() {
    # because searching for server info is done with internal id we will loop over all uuid..
    # ugly but more user friendly..
    [ -z "$1" ] && echo "Error: Please specify server UUID" && return
    server_uuids=$(getAllServers)
    echo "$(echo "$server_uuids" | grep -c "$1")"
}

# test action on all servers
#getAllServers | while IFS= read -r server_uuid; do
#    executeAction "$server_uuid" "start"
#done

# testing validity of server uuid
#isServerIDValid
#isServerIDValid cd4a6769-dbd4-41eb-9c35-8c743b747a8b
#isServerIDValid cd4a6769
#isServerIDValid cd4a6769-dbd4-41eb-9c35-8c743b747a8g
