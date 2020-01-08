#/bin/sh
IMAGENAME=gprossliner/docker-bridgenw-dump
docker build -t $IMAGENAME --build-arg IMAGENAME=$IMAGENAME docker-bridgenw-dump
