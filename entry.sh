#!/bin/sh
set -eu

manager() {

    echo "Inspecting binding '/bridgenw-dumps' to get source path"
    VOLSOURCE=$(docker inspect $HOSTNAME | jq -r ".[0].Mounts[]|select(.Destination==\"/bridgenw-dumps\")|.Source")
    if [ -z "$VOLSOURCE" ]; then
        echo '/bridgenw-dumps' is not mounted! Exit
        exit 1
    fi
    echo "Using Source Path: '$VOLSOURCE'"

    echo Inspecting container "$HOSTNAME" to get the network
    NETWORK=$(docker inspect $HOSTNAME | jq -r '.[0].NetworkSettings.Networks | keys | .[0]')
    echo Using Network: $NETWORK

    echo Inspecting network "$NETWORK" to get the bridge network interface
    NETIF=br-$(docker inspect $HOSTNAME | jq -r ".[0].NetworkSettings.Networks.\"$NETWORK\".NetworkID | .[0:12]")
    echo Using Interface: $NETIF

    # trap to stop gracefully
    trap stop INT       # CTRL+C
    trap stop TERM      # docker stop

    WORKERCMD="docker run -d -it --rm --net host -v $VOLSOURCE:/bridgenw-dumps $IMAGENAME $NETIF"
    # echo $WORKERCMD
    WORKERID=$($WORKERCMD)
    echo "Started Worker Container: '$WORKERID'"

    # stop worker startup logs for information
    sleep 1
    docker logs $WORKERID

    STOP="0"
    while :
    do
        # test for worker exit
        docker inspect $WORKERID > /dev/null
        if [ $? != 0 ]; then
            exit 2
        fi

        # test for ctrl+c 
        if [ $STOP != 0 ]; then
            docker stop $WORKERID > /dev/null
            break
        fi

        sleep  1
    done

    echo "Worker stopped, Exiting"
    exit 0
}

stop () {
    echo "Stopping worker"
    STOP=1
}


worker() {

    echo "Removing existing dumps"
    rm -f /bridgenw-dumps/*

    NETIF=$1
    ROTATE_SEC=600

    echo "Running as worker for interface $NETIF"
    echo "Write a new file every $ROTATE_SEC seconds"
    tcpdump -n -i $NETIF -U -G $ROTATE_SEC -w /bridgenw-dumps/trace-%H-%M.pcap
}

if [ "$#" == "0" ]; then
    manager
else
    worker $1
fi
