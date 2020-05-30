#!/bin/sh

# [global]
export DAEMON_DIR="/srv/daemon"
export DAEMON_DATA_DIR="/srv/daemon-data"
export PANEL_DIR="/var/www/pterodactyl"
export APP_API_KEY="Add application api key here."
export CLIENT_API_KEY="Add admin user api key here."
export PANEL_FQDN="https://Add the FQDN of your panel here."

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

