ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        cmake \
        gdb \
        lldb \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
