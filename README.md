# p4-fusion-docker

This repo contains a docker image of [p4-fusion](https://github.com/salesforce/p4-fusion). 

## Prerequisites
You must have p4 locally installed, and have run `p4trust` and 'p4login` previously.

## Usage
First, set the following environment variables:
```bash
export P4PORT=""
export P4USER=""
export P4CLIENT=""
export P4TICKETS=""
export P4TRUST=""
export P4ENVIRO=""
```

Next, create a direcotry for the converted git repo:
```bash
mkdir bare-clones
```

Then, run the docker image with the following command:
```bash
docker run -it -u $(id -u):$(id -g) \
    -e P4PORT=$P4PORT \
    -e P4USER=$P4USER \
    -e P4CLIENT=$P4CLIENT \
    -v $(pwd)/bare-clones:/p4-fusion/bare-clones \
    --mount type=bind,source="$P4TICKETS",target=/home/ubuntu/.p4tickets,readonly \
    --mount type=bind,source="$P4TRUST",target=/home/ubuntu/.p4trust,readonly \
    --mount type=bind,source="$P4ENVIRO",target=/home/ubuntu/.p4enviro,readonly \
    ghcr.io/robandpdx/p4-fusion:latest \
    /p4-fusion/build/p4-fusion/p4-fusion \
        --path //gl-exporter/... \
        --user "$P4USER" \
        --port "$P4PORT" \
        --client "$P4CLIENT" \
        --src bare-clones/gl-exporter.git \
        --networkThreads 20 \
        --printBatch 100 \
        --lookAhead 1000 \
        --retries 10 \
        --refresh 100 \
        --branch main \
        --branch release-1
```
If your local use is not `ubuntu` you'll need to modify the bind mounts in the command above to match the expected home directory of your user inside the container.  
For usage of the `p4-fusion` command above, refer to the project's [readme](https://github.com/salesforce/p4-fusion).