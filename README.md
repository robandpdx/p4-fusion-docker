# p4-fusion-docker

This repo contains a docker image of [p4-fusion](https://github.com/salesforce/p4-fusion). You can use the docker image with the following command:
```
docker run -it ghcr.io/robandpdx/p4-fusion:latest /bin/bash
```

Once in the docker container, set the following environment variables:
```
export P4USER=""
export P4PORT=""
export P4CLIENT=""
```

Then run `p4 trust` to accept your server's ssl cert. Then run `p4 client` and input your password. Then you can run p4-fusion as described in the [readme](https://github.com/salesforce/p4-fusion).