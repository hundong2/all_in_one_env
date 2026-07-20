# Docker development images

이 폴더는 로컬 컴퓨터에 toolchain을 직접 설치하기 어려운 경우를 위한 기본 빌드 환경입니다.

## Build

```bash
make docker-build DOCKER_LANG=cpp
make docker-build DOCKER_LANG=dotnet DOCKER_BUILD_ARGS="--build-arg DOTNET_SDK_TAG=10.0"
make docker-build DOCKER_LANG=dotnet DOCKER_BUILD_ARGS="--build-arg DOTNET_SDK_TAG=11.0-preview"
make docker-build DOCKER_LANG=python DOCKER_BUILD_ARGS="--build-arg PYTHON_TAG=3.13-slim"
make docker-build DOCKER_LANG=rust
make docker-build DOCKER_LANG=go
```

## Run in a project

```bash
make docker-run DOCKER_LANG=cpp PROJECT_DIR=/path/to/main-project
make docker-run DOCKER_LANG=dotnet PROJECT_DIR=/path/to/main-project
make docker-run DOCKER_LANG=python PROJECT_DIR=/path/to/main-project
make docker-run DOCKER_LANG=rust PROJECT_DIR=/path/to/main-project
make docker-run DOCKER_LANG=go PROJECT_DIR=/path/to/main-project
```

`docker/dotnet/Dockerfile`은 Microsoft .NET SDK image tag를 그대로 받습니다. preview tag는 시간이 지나며 이름이 바뀔 수 있으므로 `DOTNET_SDK_TAG`를 빌드 시점에 확인해 넘기세요.
