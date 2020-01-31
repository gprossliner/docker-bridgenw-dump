# docker-bridgenw-dump

A utility to capture all Traffic on a Docker Bridge Network to rotating .pcap files.

**When to use docker-bridgenw-dump**

It's primary usecase is to provide network dumps for development or testing.
It's not designed and tested to be a production tool.

Please note that docker-bridgenw-dump will not work with overlay networks,
only with bridge networks.

**Why use docker-bridgenw-dump instead of manually starting tcpdump on the host?**

As a docker bridge network creates a network interface on the host, it is easy 
to run tcpdump with the correct network interface. By using docker-bridgenw-dump, 
you gain the follwing advantages:

- Works with Docker for Windows: When using Docker for Windows, you have no 
access to the virtual machine running the Docker engine.
- Automatically attach to the correct network: You don't have to lookup the correct 
network interface manually. This is specially usefull in a docker-compose based 
application, where each service is attached to a network by default.

**Links**

[docker-bridgenw-dump on github](https://github.com/gprossliner/docker-bridgenw-dump)

[docker-bridgenw-dump on dockerhub](https://hub.docker.com/r/gprossliner/docker-bridgenw-dump)

## Contributing

Contribution in form of Issues, Comments and Pull-Requests are very welcome.
Please feel free to create an Issue if you have any questions.

## Usage

Requirements for a container running the `docker-bridgenw-dump` image:

- mount the Docker socket, because we need to get information from Docker
- mount a volume to the `/bridgenw-dumps` container path
- attach the container to the network you want to dump
- pass additional config parameters as environment variables, possible values are:
  - `ROTATE_SEC`: New `.pcap` file creation time in seconds, default is `600`
  - `FILTER`: Filter parameters when calling `tcpdump`. The flags: `-i`, `-G` and `-w` cannot be defined here, as they are already used, default is `-nU`

## Start manually

You can start it by `docker run`, like:

```bash
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /tmp/dumpfiles:/bridgenw-dumps \
    --net testnetwork \
    gprossliner/docker-bridgenw-dump
```

## Start with docker-compose

You can include docker-bridgenw-dump as a service in docker-compose, like:

```yaml
services:

  # our services ....

  docker-bridgenw-dump:
    image: gprossliner/docker-bridgenw-dump
    volumes:
      # /tmp/capfiles is the host directory where the .pcap files are written to
      - /tmp/capfiles:/bridgenw-dumps
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - ROTATE_SEC=400
      - FILTER=-nnSX port 80
    networks:
      # docker-bridgenw-dump dumps traffik connected to this network
      # this may also be the default network
      - testnet

  networks:
    testnet:
```

## Example

The `/docker-compose.yaml` file is a demo of how to use docker-bridgenw-dump
in docker-compose.

## How it works

When you start a docker-bridgenw-dump container, it starts in 'Manager' mode.
Because it has the Docker socket mounted from the Host, it use the hosts Docker engine.

By self-inspection within the container, we get the following information:

- The ID of the connected network, which is used to construct the name of the 
bridge adapter (br-SHORTNWID). It is required, that the container is attached
to exactly one network.

- The source path of the mount to `/bridgenw-dumps` as the target directory for the
.pcap files.

**Note:** It is expected, that the $HOSTNAME is the ID of the container, which is the
default. Don't overwrite this explicitly with `--hostname`, otherwise the container
is not able to inspect itself.

After getting this information, an additional container is started, which is attached
to the host network. It uses the same image, but starts in 'Worker' mode.

The worker uses the information provided by the manager, to execute `tcpdump` with
the following arguments:

```bash
NETIF=<br-SHORTNWID>
ROTATE_SEC=600 # rotate every 10 minutes
FILTER=-nU
tcpdump $FILTER -i $NETIF -G $ROTATE_SEC -w /bridgenw-dumps/trace-%H-%M.pcap
```

It uses the trace-%H-%M.pcap filename, where %H and %M are expanded by strftime(3).
So the target files will be named trace- and the current Hour (24h) and Minute, like:
'trace-17-00.pcap', 'trace-17-10.pcap', ...

**NOTE:** To avoid that (interleaving) files are left from a previous run, existing
files are deleted from the output directory! If you wanna keep old traces,
copy them elsewhere.

To avoid leftover containers, the Manager:

- handles SIGINT and SIGTERM to stop a running Worker
- monitors the status of the Worker to stop itself, if the Worker has stopped unexpectedly

## Build

To build the image manually, use the `./build.sh` script. It passes the `IMAGENAME`
build-arg, which will be stored in an Environment Variable. This is used to start
the worker.

## Tests

Currently there are neither Unit nor Integration Tests. The docker-bridgenw-dump
tool has been tested manually on:

* Ubuntu 18.04.3 LTS, and Docker version 18.09.7, build 2d0083d.
* Windows Version 10.0.18363 Build 18363, and Docker for Windows version 19.03.5, build 633a0ea.

If you test the tool on in a different environment, please let me know, so I may
add this to the list.

## Release Notes

The dockerhub images are automatically build an pushed by dockerhub automated build,
using the following rules:

- If anything is pushed to 'master', an image is build for the 'latest' tag
- If a release is created, it creates a tag using the vX.Y pattern, and an image
with the corresponding tag is build and pushed.

As the name of the image is included in the image itself as an environment variable,
the digests of the 'lastest' and the latest 'vX.Y...' tag will be different,
allthough they are build from the same commit.

If you use the 'latest' tag, the worker container will also use 'latest'.
If you use a version tag, the container will always use the same version.

## Return Codes

- 0: Stopped successfully
- 1: Configuration error
- 2: Worker stopped unexpectedly
