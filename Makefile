REGISTRY_NAMESPACE ?= full360
REGISTRY ?= index.docker.io
DOCKER_CI_REPO ?= $(REGISTRY)/$(REGISTRY_NAMESPACE)
USECACHE = true
DRYRUN = true

DOCKERMK := $(shell if command -v curl >/dev/null; then \
		if [ ! -e docker-ci.mk ]; then \
			curl -fsSL https://raw.githubusercontent.com/full360/docker-ci/master/docker-ci.mk -o docker-ci.mk; \
		fi \
		elif command -v wget >/dev/null; then \
		if [ ! -e docker-ci.mk ]; then \
			wget -q https://raw.githubusercontent.com/full360/docker-ci/master/docker-ci.mk; \
		fi \
		else \
			echo "cURL and wget not found..."; \
		fi)

include docker-ci.mk
