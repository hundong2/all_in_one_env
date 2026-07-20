.DEFAULT_GOAL := help

AIO_GOALS := install verify vscode docker-build docker-run harness help list targets
AIO_ARGS := $(filter-out $(AIO_GOALS),$(MAKECMDGOALS))
TARGET ?= $(strip $(AIO_ARGS))
PROJECT_DIR ?= $(CURDIR)
DOCKER_LANG ?= cpp
DOCKER_BUILD_ARGS ?=

ifeq ($(OS),Windows_NT)
AIO_RUNNER := powershell -NoProfile -ExecutionPolicy Bypass -File scripts/aio-env.ps1
else
AIO_RUNNER := bash scripts/aio-env.sh
endif

.PHONY: help list targets install verify vscode docker-build docker-run harness

help:
	@$(AIO_RUNNER) help

list targets:
	@$(AIO_RUNNER) list

install:
	@$(AIO_RUNNER) install $(TARGET) --project "$(PROJECT_DIR)"

verify:
	@$(AIO_RUNNER) verify $(TARGET) --project "$(PROJECT_DIR)"

vscode:
	@$(AIO_RUNNER) vscode $(TARGET) --project "$(PROJECT_DIR)"

docker-build:
	@docker build $(DOCKER_BUILD_ARGS) -f docker/$(DOCKER_LANG)/Dockerfile -t all-in-one-env-$(DOCKER_LANG) docker/$(DOCKER_LANG)

docker-run:
	@docker run --rm -it -v "$(PROJECT_DIR):/workspace" -w /workspace all-in-one-env-$(DOCKER_LANG)

harness:
	@$(AIO_RUNNER) harness

%:
	@:
