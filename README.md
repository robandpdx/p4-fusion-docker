# p4-fusion-docker

This repo contains a docker image of [p4-fusion](https://github.com/salesforce/p4-fusion). 

First, set the following environment variables:
```bash
export P4PORT=""
export P4USER=""
export P4CLIENT=""
```

Next, create a direcotry for the converted git repo:
```bash
mkdir clones
```

Then, run the docker image with the following command:
```bash
docker run -it \
    -e P4PORT=$P4PORT \
    -e P4USER=$P4USER \
    -e P4CLIENT=$P4CLIENT \
    -v $(pwd)/clones:/p4-fusion/clones \
    ghcr.io/robandpdx/p4-fusion:latest /bin/bash
```

Then run `p4 trust` to accept your server's ssl cert. Then run `p4 login` and input your password. Then you can run p4-fusion as described in the [readme](https://github.com/salesforce/p4-fusion).