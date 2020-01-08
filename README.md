# docker-bridgenw-dump

A utility to capture all Traffic on a Docker Bridge Network to rotating .pcap files.

Please note that docker-bridgenw-dump will not work with overlay networks,
only with bridge networks.

It's primary usecase is to provide network dumps for development or testing.
It's not designed and tested to be a production tool.

[docker-bridgenw-dump on github](https://github.com/gprossliner/docker-bridgenw-dump)

[docker-bridgenw-dump on dockerhub](https://hub.docker.com/r/gprossliner/docker-bridgenw-dump)

## Contributing

Contribution in form of Issues, Comments and Pull-Requests are welcome.
Please feel free to create an Issue if you have questions.

## Usage

Requirements for a container running the `docker-bridgenw-dump` image:
- mount the docker socket, because we need to get information from docker
- mount a volume to the `/bridgenw-dumps` ontainer path
- attach the container to the network you want to dump

## Start manually

You can start it by `docker run`, like:

```
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /tmp/dumpfiles:/bridgenw-dumps \
    --net dockeroverlaydump_testnet \
    gprossliner/docker-bridgenw-dump
```

## Start with docker-compose

You can include docker-bridgenw-dump as a service in docker-compose, like:

```yaml
services:

  docker-bridgenw-dump:
    image: gprossliner/docker-bridgenw-dump
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /tmp/files:/bridgenw-dumps
    networks:
      # docker-bridgenw-dump dumps traffik connected to this network
      # this may also be the default network
      - testnet
```

## Example

The `/docker-compose.yaml` file is a demo of how to use docker-bridgenw-dump
in docker-compose.

## How it works

When you start a docker-bridgenw-dump container, it starts in 'Manager' mode.
Because it has the docker socket mounted from the Host, it use the hosts docker engine.

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

```
NETIF=<br-SHORTNWID>
ROTATE_SEC=600 # rotate every 10 minutes
tcpdump -n -i $NETIF -U -G $ROTATE_SEC -w /bridgenw-dumps/trace-%H-%M.pcap
```

It uses the trace-%H-%M.pcap filename, where %H and %M are expanded by strftime(3).
So the target files will be named trace- and the current Hour (24h) and Minute, like:
'trace-17-00.pcap', 'trace-17-10.pcap', ...

**NOTE:** To avoid that (interleaving) files are left from a previous run, existing 
files are deleted from the output directory! If you wanna keep old traces,
copy them elsewhere.

To avoid leftover containers, the Manager:
- Handles SIGINT and SIGTERM to stop a running Worker
- Monitors the status of the Worker to stop itself, it the Worker as stopped unexpectedly

## Build

To build the image manually, use the `./build.sh` script. It passes the `IMAGENAME`
build-arg, which will be stored in an Environment Variable. This is used to start
the worker.

**NOTE:** By default, the "latest" tag will be used. You may specify another tag,
but this has not been tested yet.

## Tests

Currently there are neigher Unit nor Integration Tests. The docker-bridgenw-dump
tool has been tested manually on Ubuntu 18.04.3 LTS, and Docker version 18.09.7, build 2d0083d.

## Return Codes

- 0: Stopped successfully
- 1: Configuration error
- 2: Worker stopped unexpectedly
