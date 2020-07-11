#!/bin/sh
#H#
#H# restore-server.sh — The script will delete the server's data and download then decompress a backup into the corresponding directory.
#H#
#H# Examples:
#H#   sh restore-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d
#H#   sh restore-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d --download-only
#H#
#H# Options:
#H#   --server <uuid>   Selects a particular server
#H#   --backups-location <path || BACKUP_DESTINATION>   The directory of the backups
#H#   --daemon-data <path || DAEMON_DATA_DIR>           The directory where all servers are
#H#   --local           Tells the script to restore from a local directory
#H#   --download-only   Only downloads the backup
#H#   --help            Shows this message.

help() {
    sed -rn 's/^#H# ?//;T;p' "$0"
}

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

# accepts server-uuid($1), backups directory($2), daemon-data directory($3)
remoteRestoration() {

    printf "\n\nLooking for backups. . .\n"
    lftp -c "open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}; 
                set ftp:ssl-allow no; 
                find $2" | grep "$1"

    echo "Which date to use for the restoration? (YYYY-MM-DD):"
    read -r restorationDate

    # check if the file exists after user input
    printf "\n\nFile to be downloaded. . .\n"
    lftp -c "open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}; 
                set ftp:ssl-allow no; 
                find $2/BACKUPS-$restorationDate;" | grep "$1"

    if [ "$?" -ne 0 ]; then
        echo "Error: There was a problem with finding your backup. May be the date was invalid."
        exit
    fi

    printf "\n\nDownloading. . .\n"
    lftp -c "open -u ${FTP_USER},${FTP_PASS} ${FTP_HOST}; 
                set ftp:ssl-allow no; 
                get $2/BACKUPS-$restorationDate/$1-BACKUP-$restorationDate.tar.gz"

    if [ "$downloadOnly" = "n" ]; then
        printf "\n\nRestoring. . .\n"
        find "$3/$1" -mindepth 1 -delete 
        tar -xvzf "$1-BACKUP-$restorationDate.tar.gz" -C "$3"
        chown -R pterodactyl:pterodactyl "$3/$1"
        rm "$1-BACKUP-$restorationDate.tar.gz"
    fi 
}

# accepts server-uuid($1), backups directory($2), daemon-data directory($3)
localRestoration() {

    printf "\n\nLooking for backups. . .\n"
    find "$2" -name "$1*" -print

    echo "Which date to use for the restoration? (YYYY-MM-DD):"
    read -r restorationDate

    # check if the file exists after user input
    printf "\n\nFile to be restored. . .\n"
    find "$2/BACKUPS-$restorationDate" -name "$1-BACKUP-$restorationDate.tar.gz"

    if [ "$?" -ne 0 ]; then
        echo "Error: There was a problem with finding your backup. May be the date was invalid."
        exit
    fi

    if [ "$downloadOnly" = "n" ]; then
        printf "\n\nRestoring. . .\n"
        find "$3/$1" -mindepth 1 -delete 
        tar -xvzf "$2/BACKUPS-$restorationDate/$1-BACKUP-$restorationDate.tar.gz" -C "$3"
        chown -R pterodactyl:pterodactyl "$3/$1"
    fi
}

checkDependencies() {
    mainShellPID="$$"
    printf "lftp\ngrep\ntar\nfind" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

checkDependencies


######################
# VALIDATE ARGUMENTS #
######################

# set defaults 
server='' daemonData='' backupsLocation='' isLocalBackup='n' downloadOnly='n'

# loop over the arguments
# leaving this here just in case https://stackoverflow.com/questions/34434157/posix-sh-syntax-for-for-loops-sc2039
while [ -n "$1" ]; do

    if [ "$1" = "--server" ]; then 
        shift 
        server="$1"

    elif [ "$1" = "--backups-location" ]; then
        shift
        backupsLocation="$1"

    elif [ "$1" = "--daemon-data" ]; then
        shift
        daemonData="$1"

    elif [ "$1" = "--local" ]; then
        isLocalBackup="y"

    elif [ "$1" = "--download-only" ]; then
        downloadOnly="y"
        
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        help
        exit 0
    else 
        echo "Invalid argument: $1" && exit
    fi
    shift
done


##################
# SANITISE VARIABLES #
##################

# if server is not specified abort
[ -z "$server" ] && printf "Error: Please specify a server or \"all\"\n" >&2 && exit

# if backups-location and daemon-data are not specified default to config
[ -z "$backupsLocation" ] && backupsLocation="$BACKUP_DESTINATION" && echo "Backups' location not specified. Using the default value of BACKUP_DESTINATION!"
[ -z "$daemonData" ] && daemonData="$DAEMON_DATA_DIR" && echo "Daemon data directory not specified. Using the default value of DAEMON_DATA_DIR!"


####################
# RESTORATION PROCESS #
####################

if [ "$isLocalBackup" = "y" ]; then
    localRestoration "$server" "$backupsLocation" "$daemonData"
else
    remoteRestoration "$server" "$backupsLocation" "$daemonData"
fi




