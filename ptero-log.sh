#!/bin/bash

#./ptero-log.sh --wings --request --setup --installation <server_id> --live --panel

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
    if [[ $live == "y" ]];then
        tailf "$DAEMON_DIR/logs/wings.log" | jq -C .
    else
        cat "$DAEMON_DIR/logs/wings.log" | jq -C . | less -R +G
    fi

elif [[ $request == "y" ]];then
    if [[ $live == "y" ]];then
        tailf "$DAEMON_DIR/logs/request.log" | jq -C .
    else
        cat "$DAEMON_DIR/logs/request.log" | jq -C . | less -R +G
    fi

elif [[ -n "$installation" ]];then
    if [[ $live == "y" ]];then
        tailf -n 40 "$DAEMON_DIR/config/servers/$installation/install.log"
    else
        cat "$DAEMON_DIR/config/servers/$installation/install.log" | less -R +G
    fi
elif [[ $panel == "y" ]];then
    if [[ $live == "y" ]];then
        echo panel
    else
        echo panel
    fi
fi
