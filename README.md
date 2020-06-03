# ptero-shell-utils
This is a collection of scripts for automating different things related to the [Pterodactyl project](https://pterodactyl.io/). Ideally all of these scripts will not be needed in the future as the project develops but for now many problems and aspects remain outside the scope of development. Because of this I figured the community could benefit from such tools. Of course many of these scripts can be substituted by addons but the idea of this repository is to provide the community with easy alternatives that can be used alongside the panel and daemons without changing their code. If you have any problems or ideas feel free to contribute and help make them into a script.

# Compatibility
So far the scripts have been tested on the following distributions. It would be nice if you notify me with more information if you end up using them. I am trying to keep them POSIX compliant to ensure that there are no weird edge cases and of course to follow some form of standard to keep me sane. 

| Script | Centos 7 | Centos 8 | Ubuntu 18.04 | Ubuntu 20.04 | Debian 9 | Debian 10|
| :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| ip-mapper | ✅ | ✅ | ✅ | ❓ | ❓ | ❓ | 
| ptero-log | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 
| power-control | ✅ | ✅ | ❓ | ❓ | ❓ | ❓ | 
| backup-server | ✅ | ✅ | ❓ | ❓ | ❓ | ❓ | 
| restore-server | ✅ | ✅ | ❓ | ❓ | ❓ | ❓ | 

**There are 2 scripts ip-mapper and ip-mapper-nft for wider compatibility. Always use ip-mapper and it will tell you if you need to use the nft version if needed. This is due to newer systems shipping with nft instead of iptables or a combination of both.**

# Scripts

## ip-mapper.sh<span></span>

It basically solves [this](https://github.com/pterodactyl/panel/issues/459) problem which arises from the way docker updates iptables. The script listens for docker events and changes the NAT table of the POSTROUTING chain in iptables. Thanks to this script services with outgoing requests such as game servers to server lists can show the proper IP assigned in the panel rather than the default IP of the host. This could also resolve issues with 3rd party authentication services or enable hostings to completely change the IPs of their customers.  The script sets a static source IP as configured by the panel for all outgoing requests of the corresponding docker container. **This needs to run with root privileges because of iptables!**

**Dependencies:** docker, iptables, awk, grep, cut

**Config requirements:** None

**Usage:**

This script needs to run constantly in the background in order to keep the IPs updated.

```
sh ip-mapper.sh # Listens for docker events.
sh ip-mapper.sh [options]
    --remove all | <server_id> # Removes rules added by the script.
    --list all | <server_id> # Lists active rules added by the script.
```
Example log output: `sh ip-mapper.sh 2>&1 | tee ip-mapper.log`

You can use tmux, screen, systemd to "deamonize" the script so that it can constantly work on the background. 

Example with screen: `screen -dmS ip-mapper sh ip-mapper.sh`

Example of a systemd service:`not yet`

## ptero-log.sh<span></span>
A utility for more readable logs from the panel and daemon.

**Dependencies:** tailf, jq, less

**Config requirements:**

You will need to edit the following entries in **config.sh<span></span>** to suit your installation.
```
# [global]
export DAEMON_DIR="/srv/daemon"
export DAEMON_DATA_DIR="/srv/daemon-data"
export PANEL_DIR="/var/www/pterodactyl"
```

**Usage:**

```
sh ptero-log.sh [options] 
    --wings # Shows prettified & colored json of /srv/daemon/logs/wings.log
    --request # Shows prettified & colored json of /srv/daemon/logs/request.log
    --panel # Shows the latest log from PANEL_DIR/storage/logs
    --installation <server_id> # Shows scrollable install log of server
    --stats # Shows container's resources usage
    --live # Updates the log live
    --upload # Uploads the output to bin.ptdl.co (NOT IMPLEMENTED)

Note*: You can't use the arguments together! The only exception is --live as it can be combined with any of them.
```

**Example:**`sh ptero-log.sh --wings --live`

**Example2:**`sh ptero-log.sh --installation e13df76a-7b62-4dab-a427-6c959e5da36d --live`

## power-control.sh<span></span>
Send power commands to groups of servers based on node, owner or server UUID.

**Dependencies:** jq, grep, awk, curl

**Config requirements:**

You will need to edit the following entries in **config.sh<span></span>** to suit your installation. Note that the script needs 2 api keys, one from the application and one from an admin user because of certain limitations of the [Pterodactyl's API](https://dashflo.net/docs/api/pterodactyl/v0.7/#introduction). If you don't know how to obtain the two keys [here is a tutorial](https://github.com/Ivstiv/ptero-shell-utils/wiki/Setting-API-keys-in-the-config) that explains the process.
```
# [global]
export APP_API_KEY="Add application api key here."
export CLIENT_API_KEY="Add admin user api key here."
export PANEL_FQDN="https://Add the FQDN of your panel here."
```

**Usage:**

```
sh power-control.sh [options] 
    --server <UUID | all> # Selects a particular server or all of them
    --user <username> # Selects all servers of that user
    --node <id | empty=prompt to choose> # Selects all servers on that node
    --action <start | stop | restart | kill> # Specifies the action to be executed
    --mock # This can be used to test the script without actually sending actions
    --force # Force the execution without a confirmation prompt

Note*: You can't group multiple selector arguments together!
Note**: You can't execute multiple actions together!
```

**Example with MOCK calls:**`sh power-control.sh --node --action restart --mock`

**Stop all servers of a user:**`sh power-sontrol.sh --user user1234 --action stop`

**Kill all servers (be careful):**`sh power-sontrol.sh --server all --action kill`

## backup-server.sh<span></span>
This script aims to ease the backup process of the servers' data by providing options for remote and local backups. You can leave it
running daily in crontab to fully automate the process. 

**Dependencies:** lftp, tar, curl, find

**Config requirements:**

You will need to edit the following entries in **config.sh<span></span>** to suit your installation. A lot of the variables can also be specified as command arguments which is explained under **Usage** so you don't need to populate all of these in the config. 
```
# [global]
export DAEMON_DATA_DIR="/srv/daemon-data"

# [backup-server & restore-server]
export BACKUP_DESTINATION="/pterodactyl-backups"
export BACKUP_EXPIRATION="1 week"
export DISCORD_WEBHOOK=""
export DISCORD_BACKUP_NAME="[NODE] Example"
export DISCORD_BACKUP_MSG="Pterodactyl backups finished!"
export FTP_HOST=""
export FTP_USER=""
export FTP_PASS=""
# For adjusting your transfer speeds consult LFTP's manual: https://lftp.yar.ru/lftp-man.html
# 0 means unlimited
export TRANSFER_RATE_DOWNLOAD="0"
export TRANSFER_RATE_UPLOAD="0"
export TRANSFER_CONNECTIONS="0" 
```

**Usage:**
```
sh backup-server.sh [options]
    --server <uuid | all>   # Selects a particular server or all of them
    --origin <path || DAEMON_DATA_DIR>  # Selects the root folder of the servers' data
    --destination <destination || BACKUP_DESTINATION>   # Selects the destination folder of the backup
    --host <host || FTP_HOST>   # FTP credentials
    --user <user || FTP_USER>    # FTP credentials
    --pass <pass || FTP_PASS>   # FTP credentials

Note*: The variables in CAPS come from config.sh and they will replace the argument if it has not been explicitly specified!
Note**: If you don't have FTP credentials defined anywhere it will perform a local backup to the specified directory.
```

**Example of backup with single server with populated config:**`sh backup-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d`

**Daily backups in crontab:**`0 0 * * * screen -dmS pterodactyl-backups sh backup-server.sh --server all`

## restore-server.sh<span></span>
If used alongside the backup script above admins can easily restore servers to specified date. The script will delete the server's data and download then decompress a backup into the corresponding directory. It might be a good idea to run this script
in a tmux, screen session to be able to detach from it while the backups download. Due to their size they can take pretty long time!

**Dependencies:** lftp, tar, find, grep

**Config requirements:**

You will need to edit the following entries in **config.sh<span></span>** to suit your installation. A lot of the variables can also be specified as command arguments which is explained under **Usage** so you don't need to populate all of these in the config. 
```
# [global]
export DAEMON_DATA_DIR="/srv/daemon-data"

# [backup-server & restore-server]
export BACKUP_DESTINATION="/pterodactyl-backups"
export FTP_HOST=""
export FTP_USER=""
export FTP_PASS=""
```

**Usage:**
```
sh restore-server.sh [options]
    --server <uuid> # Selects a particular server
    --backups-location <path || BACKUP_DESTINATION> # The directory of the backups
    --daemon-data <path || DAEMON_DATA_DIR> # The directory where all servers are
    --local # Tells the script to restore from a local directory
    --download-only # Only downloads the backup

Note*: The script looks for defined FTP credentials in the config.
Note**: The script requires root permissions in order to grant ownership of the files to the deamon. 
```

**Example:**`sh restore-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d`
**Example without restoration:**`sh restore-server.sh --server e13df76a-7b62-4dab-a427-6c959e5da36d --download-only`

## transfer-server.sh<span></span>
One command solution to transferring servers between nodes!

# Contact and contribution
If you have issues, ideas or want to contribute you can [join my discord server](https://discord.gg/VMSDGVD) to have a chat and explain your situation. :)