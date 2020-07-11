#!/bin/sh
#H#
#H# backup-server.sh — Aims to ease the backup process of the servers' data by providing options for remote and local backups.
#H#
#H# Examples:
#H#   sh backup-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d
#H#   sh backup-server.sh --server all --destination /backups
#H#
#H# Options:
#H#   --server <uuid | all>         Selects a particular server or all of them
#H#   --origin <path || DAEMON_DATA_DIR>                    Selects the root folder of the servers' data
#H#   --destination <destination || BACKUP_DESTINATION>     Selects the destination folder of the backup
#H#   --host <host || FTP_HOST>     FTP credentials
#H#   --user <user || FTP_USER>     FTP credentials
#H#   --pass <pass || FTP_PASS>     FTP credentials
#H#   --help            Shows this message.

help() {
    sed -rn 's/^#H# ?//;T;p' "$0"
}

project_root=$(dirname "$(realpath "$0")")
# shellcheck source=/dev/null
. "$project_root/config.sh"

# Variables
DATE_CREATE=$(date +%Y-%m-%d)
DATE_DELETE=$(date --date="-$BACKUP_EXPIRATION" +%Y-%m-%d)
BACKUP_SUFFIX="-BACKUP-${DATE_CREATE}.tar.gz"

checkDependencies() {
    mainShellPID="$$"
    printf "lftp\ncurl\nfind\ntar" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

checkDependencies


####################
# VALIDATE ARGUMENTS  #
####################

# set defaults 
server='' origin='' destination='' host='' user='' pass='' isLocalBackup='n'

# loop over the arguments
# leaving this here just in case https://stackoverflow.com/questions/34434157/posix-sh-syntax-for-for-loops-sc2039
while [ -n "$1" ]; do

    if [ "$1" = "--server" ]; then 
        shift 
        server="$1"

    elif [ "$1" = "--origin" ]; then
        shift
        origin="$1"

    elif [ "$1" = "--destination" ]; then
        shift
        destination="$1"

    elif [ "$1" = "--host" ]; then
        shift
        host="$1"

    elif [ "$1" = "--user" ]; then
        shift
        user="$1"

    elif [ "$1" = "--pass" ]; then
        shift
        pass="$1"

    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        help
        exit 0
    else 
        echo "Invalid argument: $1" && exit
    fi
    shift
done


##################
# SANITISE VARIABLES  #
##################

# if server is not specified abort
[ -z "$server" ] && printf "Error: Please specify a server or \"all\"\n" >&2 && exit

# if origin and destination are not specified default to config
[ -z "$origin" ] && origin="$DAEMON_DATA_DIR" && echo "Origin not specified. Using the default value of DAEMON_DATA_DIR!"
[ -z "$destination" ] && destination="$BACKUP_DESTINATION" && echo "Destination not specified. Using the default value of BACKUP_DESTINATION!"

# if remote details are not specified copy those form the config
[ -z "$host" ] && host="$FTP_HOST"
[ -z "$user" ] && user="$FTP_USER"
[ -z "$pass" ] && pass="$FTP_PASS"

# if host, user and pass are not specified it is a local backup
if [ -z "$host" ] && [ -z "$user" ] && [ -z "$pass" ]; then
    isLocalBackup='y'
elif [ -z "$host" ] || [ -z "$user" ] || [ -z "$pass" ]; then
    echo "Error: You are missing either --host, --user or --pass for your remote destination!" >&2
    exit
fi


#################
# PREPARE FOLDERS   #
#################

echo "Removing old backup folder: $destination/BACKUPS-$DATE_DELETE"
echo "Creating new backup folder: $destination/BACKUPS-$DATE_CREATE"

if [ "$isLocalBackup" = "y" ]; then
    rm -rf "$destination/BACKUPS-$DATE_DELETE"
    mkdir -p "$destination/BACKUPS-$DATE_CREATE"
else
    lftp -c "open -u $user,$pass $host; 
                set ftp:ssl-allow no; 
                rm -r $destination/BACKUPS-$DATE_DELETE; 
                mkdir -p $destination/BACKUPS-$DATE_CREATE;" 
fi


################
# BACKUP PROCESS #
################

# otherwise the backups will have full names
cd "$origin" || exit
if [ "$server" = "all" ]; then
    # can't use "for d in */"" because of posix.. :D 
    find "$origin" -maxdepth 1 -mindepth 1 -not -path '*/\.*' -type d -printf '%f\n' | while IFS= read -r dir; do

        if [ "$isLocalBackup" = "y" ]; then
            echo "Compressing: $origin/$dir"
            tar -czf "$destination/BACKUPS-$DATE_CREATE/${dir}${BACKUP_SUFFIX}" "$dir";
        else
            echo "Compressing: $origin/$dir"
            tar -czf "${dir}${BACKUP_SUFFIX}" "$dir";
            echo "Uploading: ${dir}${BACKUP_SUFFIX}"
            lftp -c "open -u $user,$pass $host;
                        set ftp:ssl-allow no;
                        set net:connection-limit $TRANSFER_CONNECTIONS;
                        set net:limit-rate $TRANSFER_RATE_DOWNLOAD:$TRANSFER_RATE_UPLOAD;
                        put -O $destination/BACKUPS-$DATE_CREATE ${dir}${BACKUP_SUFFIX}";
            rm "${dir}${BACKUP_SUFFIX}"
        fi

    done
else
    # backup only the specified server
    if [ "$isLocalBackup" = "y" ]; then
        echo "Compressing: $origin/$server"
        tar -czf "$destination/BACKUPS-$DATE_CREATE/${server}${BACKUP_SUFFIX}" "$server";
    else
        echo "Compressing: $origin/$server"
        tar -czf "${server}${BACKUP_SUFFIX}" "$server";
        echo "Uploading: ${server}${BACKUP_SUFFIX}"
        lftp -c "open -u $user,$pass $host;
                    set ftp:ssl-allow no;
                    set net:connection-limit $TRANSFER_CONNECTIONS;
                    set net:limit-rate $TRANSFER_RATE_DOWNLOAD:$TRANSFER_RATE_UPLOAD;
                    put -O $destination/BACKUPS-$DATE_CREATE ${server}${BACKUP_SUFFIX}";
        rm "${server}${BACKUP_SUFFIX}"
    fi
fi


#####################
# DISCORD NOTIFICATION  #
#####################
if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -H "Content-Type: application/json" -X POST -d "{\"username\": \"$DISCORD_BACKUP_NAME\", \"embeds\": [{\"title\": \"$DISCORD_BACKUP_MSG\"}]}" "$DISCORD_WEBHOOK"
fi