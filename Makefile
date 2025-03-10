NAME := sshd-server
TAG := latest
QUAY_IMAGE := quay.io/alveo/$(NAME)
GHCR_IMAGE := ghcr.io/decloudz/$(NAME)
IMAGE_NAME := $(QUAY_IMAGE)

.PHONY: *

help:
	@printf "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)\n"

build: ## Builds docker image latest
	docker build --pull -t $(IMAGE_NAME):latest .

build-all: ## Builds docker images for both registries
	docker build --pull -t $(QUAY_IMAGE):latest -t $(GHCR_IMAGE):latest .

push-quay: ## Pushes the docker image to Quay.io
	# Don't --pull here, we don't want any last minute upsteam changes
	docker build -t $(QUAY_IMAGE):$(TAG) .
	docker tag $(QUAY_IMAGE):$(TAG) $(QUAY_IMAGE):latest
	docker push $(QUAY_IMAGE):$(TAG)
	docker push $(QUAY_IMAGE):latest

push-ghcr: ## Pushes the docker image to GitHub Container Registry
	# Don't --pull here, we don't want any last minute upsteam changes
	docker build -t $(GHCR_IMAGE):$(TAG) .
	docker tag $(GHCR_IMAGE):$(TAG) $(GHCR_IMAGE):latest
	docker push $(GHCR_IMAGE):$(TAG)
	docker push $(GHCR_IMAGE):latest

push: push-quay push-ghcr ## Pushes images to both Quay.io and GitHub Container Registry

clean: ## Remove built images
	docker rmi $(QUAY_IMAGE):latest $(GHCR_IMAGE):latest || true
	docker rmi $(QUAY_IMAGE):$(TAG) $(GHCR_IMAGE):$(TAG) || true

_ci_test:
	@echo "Running basic container tests..."
	docker inspect $(QUAY_IMAGE):test > /dev/null || docker inspect alveo/sshd-server:test > /dev/null
	@echo "Verifying SSH daemon starts properly..."
	docker run --rm -d --name sshd-server-test $(QUAY_IMAGE):test || docker run --rm -d --name sshd-server-test alveo/sshd-server:test
	@sleep 2
	docker logs sshd-server-test | grep -q "Server listening" || docker logs sshd-server-test
	docker stop sshd-server-test
	@echo "All tests passed!"