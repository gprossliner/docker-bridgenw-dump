#/bin/sh
IMAGENAME=gprossliner/docker-bridgenw-dump
docker build -t $IMAGENAME --build-arg IMAGENAME=$IMAGENAME .

docker build -t docker-bridgenw-dump-testclient ./testclient

