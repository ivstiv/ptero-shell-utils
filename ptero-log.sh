#!/bin/sh

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

# set defaults 
setup=n wings=n request=n panel=n installation='' live=n
uniqueArguments=0

# loop over the arguments
# leaving this here just in case https://stackoverflow.com/questions/34434157/posix-sh-syntax-for-for-loops-sc2039
while [ -n "$1" ]; do
    if [ "$1" = "--setup" ]; then 
        setup=y
        uniqueArguments=$(( uniqueArguments+1))
        # TO-DO: add an installation function that checks for distro
    elif [ "$1" = "--wings" ]; then
        wings=y
        uniqueArguments=$(( uniqueArguments+1))
    elif [ "$1" = "--request" ]; then
        request=y
        uniqueArguments=$(( uniqueArguments+1))
    elif [ "$1" = "--panel" ]; then
        panel=y
        uniqueArguments=$(( uniqueArguments+1))
    elif [ "$1" = "--installation" ]; then
        shift
        installation="$1"
        uniqueArguments=$(( uniqueArguments+1))
    elif [ "$1" = "--live" ]; then
        live=y
    else 
        echo "Invalid argument: $1" && exit
    fi
    shift
done

[ "$uniqueArguments" -gt 1 ] && echo "Error: You need to choose either --setup, --wings, --request, --panel or --installation <server_id> but not together!" && exit

if [ "$setup" = "y" ];then
    echo "install dependencies"

elif [ "$wings" = "y" ];then

    # validate that the file exists
    [ ! -f "$DAEMON_DIR/logs/wings.log" ] && echo "Couldn't find: $DAEMON_DIR/logs/wings.log" && exit

    if [ "$live" = "y" ];then
        tailf "$DAEMON_DIR/logs/wings.log" | jq -C .
    else
        "$DAEMON_DIR/logs/wings.log" | jq -C . | less -R +G
    fi

elif [ "$request" = "y" ];then

    # validate that the file exists
    [ ! -f "$DAEMON_DIR/logs/request.log" ] && echo "Couldn't find: $DAEMON_DIR/logs/request.log" && exit

    if [ "$live" = "y" ];then
        tailf "$DAEMON_DIR/logs/request.log" | jq -C .
    else
        "$DAEMON_DIR/logs/request.log" | jq -C . | less -R +G
    fi

elif [ -n "$installation" ];then

    # validate that the file exists
    [ ! -f "$DAEMON_DIR/config/servers/$installation/install.log" ] && echo "Couldn't find: $DAEMON_DIR/config/servers/$installation/install.log" && exit

    if [ "$live" = "y" ];then
        tailf -n 40 "$DAEMON_DIR/config/servers/$installation/install.log"
    else
        "$DAEMON_DIR/config/servers/$installation/install.log" | less -R +G
    fi
    
elif [ "$panel" = "y" ];then

    # validate that the file exists
    [ ! -f "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" ] && echo "Couldn't find: $PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" && exit

    if [ "$live" = "y" ];then
        tailf -n 40 "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    else
        less +G "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    fi
fi
