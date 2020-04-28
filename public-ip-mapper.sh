#!/bin/sh
 
echo Listening for docker events... 
docker events --filter type=container --format '{{.Status}} {{.Actor.Attributes.name}}' | while read event

do
	status=$(echo $event | awk '{print $1}')
	if [[ $status == 'start' ]]; then
		name=$(echo $event | awk '{print $2}')
		local_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $name)
		public_ip=$(docker exec $name printenv SERVER_IP)
		
		echo "========================================="
		echo $(date)
		echo -e "Status=$status\nName=$name\nLocal_IP=$local_ip\nPublic_IP=$public_ip"
		echo "Action: Adding to NAT"
		echo "========================================="
		# remove old rules with this local ip (but this will delete docker rules so fix that. check iptables -t nat -L POSTROUTING to understand :D)
		# remove old rules with this comment 
		# add new rule iptables -t nat -I POSTROUTING -s <local_ip> -j SNAT --to <public_ip> --comment <name>
	elif [[ $status == 'die' ]]; then
		name=$(echo $event | awk '{print $2}')
		
		echo "========================================="
		echo $(date)
		echo "Name=$name"
		echo "Action: Remove from NAT by name"
		echo "========================================="
		# remove old rules with this comment 
	fi
	
	# You can configure all events from here: https://docs.docker.com/engine/reference/commandline/events/
    
done

# -start
# attach
# exec_create
# exec_start
# kill / no public ip on 2nd kick after stop
# die / no local,public ip
# stop / no local,public ip