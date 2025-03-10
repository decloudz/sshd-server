NAME := sshd-server
TAG := latest
QUAY_IMAGE := quay.io/alveo/$(NAME)
GHCR_IMAGE := ghcr.io/decloudz/$(NAME)
IMAGE_NAME := $(QUAY_IMAGE)
TEST_IMAGE ?= sshd-server:test  # Default, can be overridden with env var

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
	@echo "Testing image: $(TEST_IMAGE)"
	docker inspect $(TEST_IMAGE) > /dev/null || (echo "Error: Test image $(TEST_IMAGE) not found" && exit 1)
	
	@echo "Verifying container can start..."
	@# Remove any existing test container
	docker rm -f sshd-server-test 2>/dev/null || true
	
	@# Run container with explicit flag to keep it running even if entrypoint fails
	docker run --rm -d --name sshd-server-test $(TEST_IMAGE) || (echo "Container failed to start" && exit 1)
	
	@# Give container time to initialize or crash
	sleep 3
	
	@# Check if container is still running
	docker ps | grep sshd-server-test || { \
		echo "Container exited prematurely. Checking logs:"; \
		docker logs sshd-server-test || echo "No logs available, container likely crashed immediately"; \
		echo "Testing with interactive run to debug:"; \
		docker run --rm -it $(TEST_IMAGE) /bin/sh -c "echo 'Testing entrypoint' && /usr/local/bin/entrypoint.sh echo 'Entrypoint works'"; \
		exit 1; \
	}
	
	@echo "Container is running, checking logs:"
	docker logs sshd-server-test
	
	@echo "Stopping test container..."
	docker stop sshd-server-test
	
	@echo "All tests passed!"