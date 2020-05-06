#!/bin/bash

project_root=$(dirname $(realpath $0))
source "$project_root/config.sh"

# set defaults 
setup=n wings=n request=n panel=n installation='' live=n
uniqueArguments=0

# process arguments
for (( i=1; i<=$#; i++)); do
    if [[ "${!i}" == "--setup" ]]; then
        setup=y
        ((uniqueArguments++))
    elif [[ "${!i}" == "--wings" ]]; then
        wings=y
        ((uniqueArguments++))
    elif [[ "${!i}" == "--request" ]]; then
        request=y
        ((uniqueArguments++))
    elif [[ "${!i}" == "--panel" ]]; then
        panel=y
        ((uniqueArguments++))
    elif [[ "${!i}" == "--installation" ]]; then
        nextIndex=$((i+1))
        installation=${!nextIndex}
        ((uniqueArguments++))
    elif [[ "${!i}" == "--live" ]]; then
        live=y
    fi
done

[[ "$uniqueArguments" > 1 ]] && echo "Error: You need to choose either --setup, --wings, --request, --panel or --installation <server_id> but not together!" && exit

if [[ $setup == "y" ]];then
    echo "install dependencies"

elif [[ $wings == "y" ]];then

    # validate that the file exists
    [[ ! -f "$DAEMON_DIR/logs/wings.log" ]] && echo "Couldn't find: $DAEMON_DIR/logs/wings.log" && exit

    if [[ $live == "y" ]];then
        tailf "$DAEMON_DIR/logs/wings.log" | jq -C .
    else
        cat "$DAEMON_DIR/logs/wings.log" | jq -C . | less -R +G
    fi

elif [[ $request == "y" ]];then

    # validate that the file exists
    [[ ! -f "$DAEMON_DIR/logs/request.log" ]] && echo "Couldn't find: $DAEMON_DIR/logs/request.log" && exit

    if [[ $live == "y" ]];then
        tailf "$DAEMON_DIR/logs/request.log" | jq -C .
    else
        cat "$DAEMON_DIR/logs/request.log" | jq -C . | less -R +G
    fi

elif [[ -n "$installation" ]];then

    # validate that the file exists
    [[ ! -f "$DAEMON_DIR/config/servers/$installation/install.log" ]] && echo "Couldn't find: $DAEMON_DIR/config/servers/$installation/install.log" && exit

    if [[ $live == "y" ]];then
        tailf -n 40 "$DAEMON_DIR/config/servers/$installation/install.log"
    else
        cat "$DAEMON_DIR/config/servers/$installation/install.log" | less -R +G
    fi
    
elif [[ $panel == "y" ]];then

    # validate that the file exists
    [[ ! -f "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" ]] && echo "Couldn't find: $PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" && exit

    if [[ $live == "y" ]];then
        tailf -n 40 "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    else
        less +G "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    fi
fi
