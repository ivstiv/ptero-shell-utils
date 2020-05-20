# ptero-shell-utils
This is a collection of scripts for automating different things related to the [Pterodactyl project](https://pterodactyl.io/). Ideally all of these scripts will not be needed in the future as the project develops but for now many problems and aspects remain outside the scope of development. Because of this I figured the community could benefit from such tools. Of course many of these scripts can be substituted by addons but the idea of this repository is to provide the community with easy alternatives that can be used alongside the panel and daemons without changing their code. If you have any problems or ideas feel free to contribute and help make them into a script.

# Compatibility
So far the scripts have been tested on the following distributions. It would be nice if you notify me with more information if you end up using them. I am trying to keep them POSIX compliant to ensure that there are no weird edge cases and of course to follow some form of standard to keep me sane. 

| Script | Centos 7 | Centos 8 | Ubuntu 18.04 | Ubuntu 20.04 | Debian 9 | Debian 10|
| :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| ip-mapper | ✅ | ⛔ | ❓ | ❓ | ❓ | ⛔ | 
| ptero-log | ✅ | ❓ | ❓ | ❓ | ❓ | ❓ | 
| power-control | ✅ | ❓ | ❓ | ❓ | ❓ | ❓ | 

**Currently ip-mapper does not work with nftables, so consider this before using it on new-ish distributions.**

# Scripts

## ip-mapper.sh<span></span>

It basically solves [this](https://github.com/pterodactyl/panel/issues/459) problem which arises from the way docker updates iptables. The script listens for docker events and changes the NAT table of the POSTROUTING chain in iptables. Thanks to this script services with outgoing requests such as game servers to server lists can show the proper IP assigned in the panel rather than the default IP of the host. This could also resolve issues with 3rd party authentication services or enable hostings to completely change the IPs of their customers.  The script sets a static source IP as configured by the panel for all outgoing requests of the corresponding docker container. **This needs to run with root privileges because of iptables!**

**Dependencies:** docker, iptables, awk, grep, cut

**Config requirements:** None

**Usage:**

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

You will need to edit the following entries in **config.sh<span></span>** to suit your installation. Note that the script needs 2 api keys, one from the application and one from an admin user because of certain limitations of the [Pterodactyl's API](https://dashflo.net/docs/api/pterodactyl/v0.7/#introduction).
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

## transfer-server.sh<span></span>
One command solution to transferring servers between nodes!

## backup-server.sh<span></span>
This script aims to ease the backup process of the daemon data by providing options for remote and local backups.

## restore-server.sh<span></span>
If used alongside the backup script above admins can easily restore servers to specified date.

# Contact and contribution
If you have issues, ideas or want to contribute you can [join my discord server](https://discord.gg/VMSDGVD) to have a chat and explain your situation. :)