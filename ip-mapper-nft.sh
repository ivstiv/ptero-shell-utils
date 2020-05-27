#!/bin/sh
# Solution to this problem: https://github.com/pterodactyl/panel/issues/459
# Reference to iptables NAT tutorial: https://www.karlrupp.net/en/computer/nat_tutorial

removeRule() {
    echo "Removing rules from nat IP-MAPPER-POSTROUTING: $1"
    rules=$(/usr/sbin/nft list chain nat IP-MAPPER-POSTROUTING -a | grep "$1" | cut -f 1 -d ' ' --complement)
    if [ -z "$rules" ]; then
        echo "Couldn't find any references."
    else
        echo "$rules" | while IFS= read -r rule; do
            handleNumber=$(echo "$rule" | awk '{print $NF}')
            # using eval to expand $rule before the command
            eval /usr/sbin/nft delete rule nat IP-MAPPER-POSTROUTING handle "$handleNumber"
            echo "Removed: $rule"
        done
    fi
}

listRule() {
    rules=$(/usr/sbin/nft list chain nat IP-MAPPER-POSTROUTING | grep "$1" | cut -f 1 -d ' ' --complement)
    if [ -z "$rules" ]; then
        echo "Couldn't find any references."
    else
        echo "$rules" | while IFS= read -r rule; do
            formattedRule=$(echo "$rule" | awk '{ $12 = substr($12, 12, 36); print $12" :: "$2" -> "$10; }')
            echo "$formattedRule"
        done
    fi
}

checkDependencies() {
    mainShellPID="$$"
    printf "docker\ngrep\nawk\nnft\ncut" | while IFS= read -r program; do
        if ! [ -x "$(command -v "$program")" ]; then
            echo "Error: $program is not installed." >&2
            kill -9 "$mainShellPID" 
        fi
    done
}

checkDependencies

#setting up the table and chain 
nft add table ip nat
# priority needs to be lower than POSTROUTING chain of docker which is 100
nft add chain nat IP-MAPPER-POSTROUTING \{type nat hook postrouting priority 50\; policy accept\;\}

if [ "$1" = "--remove" ]; then
    # quick validation
    [ -z "$2" ] && echo 'Specify server id or "all"' && exit
    [ "$2" = "all" ] && removeRule ip-mapper || removeRule "$2"
    exit

elif [ "$1" = "--list" ]; then
    # quick validation
    [ -z "$2" ] && echo 'Specify server id or "all"' && exit
    [ "$2" = "all" ] && listRule ip-mapper || listRule "$2"
    exit
fi

echo "Listening for docker events..."
docker events --filter type=container --format '{{.Status}} {{.Actor.Attributes.name}}' | while read -r event

do
    status=$(echo "$event" | awk '{print $1}')
    if [ "$status" = 'start' ]; then
        server_id=$(echo "$event" | awk '{print $2}')
        local_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$server_id")
        public_ip=$(docker exec "$server_id" printenv SERVER_IP)
        
        echo "========================================="
        date
        echo "Status=$status"
        echo "Server_ID=$server_id"
        echo "Local_IP=$local_ip"
        echo "Public_IP=$public_ip"
        echo "Action: Adding to NAT"
        echo "Trying to remove old rules just in case..."
        removeRule "$server_id"
        echo "Adding the new rule..."
        
        if [ -z "$public_ip" ]; then
            echo "Missing environmental variable: SERVER_IP"
            echo "Cannot be added to nftables!"
        else
            # add new rule 
            #eval /sbin/iptables -t nat -I POSTROUTING -s "$local_ip" -j SNAT --to "$public_ip" -m comment --comment ip-mapper-"$server_id" -w
            eval nft insert rule nat IP-MAPPER-POSTROUTING ip saddr "$local_ip" counter snat to "$public_ip" comment \"ip-mapper-"$server_id"\"
            echo "Finished."
        fi
        echo "========================================="
    elif [ "$status" = 'die' ]; then
        server_id=$(echo "$event" | awk '{print $2}')
        
        echo "========================================="
        date
        echo "Status=$status"
        echo "Server_ID=$server_id"
        echo "Action: Removing from NAT by Server ID"
        removeRule "$server_id"
        echo "Finished."
        echo "========================================="
    fi
    
    # You can configure all events from here: https://docs.docker.com/engine/reference/commandline/events/
    
done

# Why I chose to use the die event
# kill - no public ip on 2nd kick after stop (kicks 2 times on stop? wtf)
# die - no local,public ip (Kicks only once always)
# stop - no local,public ip (Doesn't kick on kill)