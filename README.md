# ptero-bash-utils
This is a collection of scripts for automating different things related to the [Pterodactyl project](https://pterodactyl.io/). Ideally all of these scripts will not be needed in the future as the project develops but for now many problems and aspects remain outside the scope of development. Because of this I figured the community could benefit from such tools. Of course many of these scripts can be substituted by addons but the idea of this repository is to provide the community with easy alternatives that can be used alongside the panel and daemons without changing their code. If you have any problems or ideas feel free to contribute and help make them into a script.

# Scripts

## public-ip-mapper.sh<span></span>

It basically solves [this](https://github.com/pterodactyl/panel/issues/459) problem which arises from the way docker works. The script listens for docker events and changes the NAT table of the POSTROUTING chain in iptables. Thanks to this script services with outgoing requests such as game servers to server lists can show the proper IP assigned in the panel rather than the default IP of the host. This could also resolve issues with 3rd party authentication services or enable hostings to completely change the IPs of their customers.  The script sets a static source IP as configured by the panel for all outgoing requests of the corresponding docker container. **This needs to run with root privileges because of iptables!**

**Config requirements:** None

**Usage:**

```
sh public-ip-mapper.sh | Listens for docker events.
sh public-ip-mapper.sh --remove all | Removes all rules added by the script.
sh public-ip-mapper.sh --remove <server_id> | Removes rules added by the script for specific server.
```
Example log output: `sh public-ip-mapper.sh 2>&1 | tee ip-mapper.log`

You can use tmux, screen, systemd to "deamonize" the script so that it can constantly work on the background. 

Example with screen: `screen -dmS public-ip-mapper sh public-ip-mapper.sh`

Example of a systemd service:`not yet`

## ptero-log.sh<span></span>
A utility for more readable logs from the panel and the daemon.

**Config requirements:**
You will need to edit the following entries in **config.sh<span></span>** to suit your installation.
```
# [global]
export DAEMON_DIR="/srv/daemon"
export DAEMON_DATA_DIR="/srv/daemon-data"
```

**Usage:**

```
sh ptero-log.sh [options] 
    --setup | Installs needed dependencies
    --wings | Shows prettified & colored json of /srv/daemon/logs/wings.log
    --request | Shows prettified & colored json of /srv/daemon/logs/request.log
    --panel |
    --installation <server_id> | Shows scrollable install log of server
    --live | Updates the log every live 
```

**Example:**`sh ptero-log.sh --wings --live`
**Example2:**`sh ptero-log.sh --installation e13df76a-7b62-4dab-a427-6c959e5da36d --live`

## transfer-server.sh<span></span>
One command solution to transferring servers between nodes!

## backup-server.sh<span></span>
This script aims to ease the backup process of the daemon data by providing options for remote and local backups.

## restore-server.sh<span></span>
If used alongside the backup script above admins can easily restore servers to specified date.

# Contact and contribution
If you have issues, ideas or want to contribute you can [join my discord server](https://discord.gg/VMSDGVD) to have a chat and explain your situation. :)