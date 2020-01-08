FROM alpine


ARG DOCKER_CLI_VERSION="17.06.2-ce"
ARG IMAGENAME=gprossliner/docker-bridgenw-dump
ENV IMAGENAME=$IMAGENAME

# install docker client
ENV DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_CLI_VERSION.tgz"

RUN apk --update add curl \
    && mkdir -p /tmp/download \
    && curl -L $DOWNLOAD_URL | tar -xz -C /tmp/download \
    && mv /tmp/download/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/download

# install everything else
RUN apk add tcpdump jq

VOLUME /bridgenw-dumps
COPY entry.sh .
RUN chmod +x entry.sh
ENTRYPOINT [ "./entry.sh" ]
