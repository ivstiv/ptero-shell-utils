sh power-control.sh --action start|stop|restart|kill --server <all | server_id>
sh power-control.sh --action start|stop|restart|kill --user <nickname or email>
sh power-control.sh --action start|stop|restart|kill --node <name or id | empty=prompt to choose>

| jq -C . | less -R +G

pseudocode of the script

--server 
    if all servers get them
    curl "https://pterodactyl.app/api/application/servers" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X GET 
    go through the pagination (replace the link with the link at the end of the response)
    execute action

    check if it exists
    curl "https://pterodactyl.app/api/application/servers/<internal-id>" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X GET 
    
    execute action
    curl "https://pterodactyl.app/api/client/servers/<id>/power" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X POST \
        -d '{ "signal": "start" }'

--user
    get all users
    curl "https://pterodactyl.app/api/application/users" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X GET 

    iterate the pagination until one of them matches username or email
    get user id from response

    get all servers 
    curl "https://pterodactyl.app/api/application/servers" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X GET 
    iterate the pagination and find all servers that have a user with the same id
    save the uuids of the servers

    execute action on all of them
    curl "https://pterodactyl.app/api/client/servers/<id>/power" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X POST \
        -d '{ "signal": "start" }'

--node 
    get all nodes
    curl "https://pterodactyl.app/api/application/nodes" \
        -H "Authorization: Bearer meowmeowmeow" \
        -H "Content-Type: application/json" \
        -H "Accept: Application/vnd.pterodactyl.v1+json" \
        -X GET 

    if argument is empty display names and ids
    wait for input
    find a node that matches id or name
    save the id

    get all servers
    iterate the pagination and find all servers with the same node id
    save them and execute action on them