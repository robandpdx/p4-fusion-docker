FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        openssl \
        libssl-dev \
        pkg-config

RUN git clone https://github.com/salesforce/p4-fusion.git
RUN curl -o p4api-glibc2.3-openssl3.tgz https://cdist2.perforce.com/perforce/r24.1/bin.linux26x86_64/p4api-glibc2.3-openssl3.tgz
RUN tar zxf p4api-glibc2.3-openssl3.tgz
RUN mkdir -p p4-fusion/vendor/helix-core-api/linux
RUN mv p4api-2024.1.2724731/* p4-fusion/vendor/helix-core-api/linux/

WORKDIR /p4-fusion
RUN ./generate_cache.sh Debug && ./build.sh

