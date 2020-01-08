#!/bin/sh
url=http://server?host=$HOSTNAME
while :
do
    echo GET $url
    curl $url 2>/dev/null > /dev/null
    echo $?
    sleep 5
done

