#!/bin/sh
#H#
#H# ptero-log.sh — A utility for more readable logs from the panel and daemon.
#H#
#H# Examples:
#H#   sh ptero-log.sh --wings --live
#H#   sh ptero-log.sh --installation e13df76a-7b62-4dab-a427-6c959e5da36d
#H#
#H# Options:
#H#   --wings       Shows prettified & colored json of /srv/daemon/logs/wings.log
#H#   --request     Shows prettified & colored json of /srv/daemon/logs/request.log
#H#   --panel       Shows the latest log from PANEL_DIR/storage/logs
#H#   --installation <server_id>    Shows scrollable install log of server
#H#   --stats       Shows container's resources usage
#H#   --live        Updates the log live
#H#   --upload      Uploads the output to bin.ptdl.co (NOT IMPLEMENTED)
#H#   --help        Shows this message.

help() {
    sed -rn 's/^#H# ?//;T;p' "$0"
}

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

checkDependencies() {
    mainShellPID="$$"
    printf "jq\ntailf\nless" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

checkDependencies

# set defaults 
setup=n wings=n request=n panel=n installation='' live=n stats=n
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
    elif [ "$1" = "--stats" ]; then
        stats=y
        uniqueArguments=$(( uniqueArguments+1))
    elif [ "$1" = "--live" ]; then
        live=y
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        help
        exit 0
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
        jq -C . "$DAEMON_DIR/logs/request.log" | less -R +G
    fi

elif [ "$request" = "y" ];then

    # validate that the file exists
    [ ! -f "$DAEMON_DIR/logs/request.log" ] && echo "Couldn't find: $DAEMON_DIR/logs/request.log" && exit

    if [ "$live" = "y" ];then
        tailf "$DAEMON_DIR/logs/request.log" | jq -C .
    else
        jq -C . "$DAEMON_DIR/logs/request.log" | less -R +G
    fi

elif [ -n "$installation" ];then

    # validate that the file exists
    [ ! -f "$DAEMON_DIR/config/servers/$installation/install.log" ] && echo "Couldn't find: $DAEMON_DIR/config/servers/$installation/install.log" && exit

    if [ "$live" = "y" ];then
        tailf -n 40 "$DAEMON_DIR/config/servers/$installation/install.log"
    else
        less -R +G "$DAEMON_DIR/config/servers/$installation/install.log"
    fi
    
elif [ "$panel" = "y" ];then

    # validate that the file exists
    [ ! -f "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" ] && echo "Couldn't find: $PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log" && exit

    if [ "$live" = "y" ];then
        tailf -n 40 "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    else
        less +G "$PANEL_DIR/storage/logs/laravel-$(date '+%Y-%m-%d').log"
    fi

elif [ "$stats" = "y" ];then
    docker stats
fi
