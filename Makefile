GO    := GO111MODULE=on go
GOOS = $(shell uname -s | tr A-Z a-z)
GOARCH = $(subst x86_64,amd64,$(patsubst i%86,386,$(shell uname -m)))
PROMU := $(GOPATH)/bin/promu
pkgs   = $(shell $(GO) list ./... | grep -v /vendor/)

PREFIX                  ?= .build/$(GOOS)-$(GOARCH)
BIN_DIR                 ?= .build/$(GOOS)-$(GOARCH)
DOCKER_REPO             ?= "ghcr.io/jeffmontagna"
DOCKER_IMAGE_NAME       ?= smartctl-exporter
DOCKER_IMAGE_TAG        ?= $(subst /,-,$(shell git rev-parse --abbrev-ref HEAD))

PUSHTAG                 ?= type=registry,push=true
DOCKER_PLATFORMS        ?= linux/amd64

all: format build test

style:
	@echo ">> checking code style"
	@! gofmt -d $(shell find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

test:
	@echo ">> running tests"
	@$(GO) test -short $(pkgs)

format:
	@echo ">> formatting code"
	@$(GO) fmt $(pkgs)

vet:
	@echo ">> vetting code"
	@$(GO) vet $(pkgs)

build: promu
	@echo ">> building binaries $(GOOS)-$(GOARCH)"
	@$(GO) mod vendor
	@$(PROMU) build --prefix=$(BIN_DIR)

crossbuild: promu
	@echo ">> crossbuilding binaries"
	@$(PROMU) crossbuild --go=1.20

tarball: promu
	@echo ">> building release tarball"
	@$(PROMU) tarball --prefix $(PREFIX) $(BIN_DIR)

docker: build
	@echo ">> building docker image, $(DOCKER_IMAGE_NAME)/$(DOCKER_IMAGE_TAG)"
	@docker build -t "$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" --build-arg BIN_DIR=$(BIN_DIR) .

docker-publish: build
	@echo ">> building and pushing docker image,  $(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(GIT_TAG_NAME)"
	@docker build -t "$(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(GIT_TAG_NAME)" --build-arg BIN_DIR=$(BIN_DIR) .
	@docker push $(DOCKER_REPO)/$(DOCKER_IMAGE_NAME):$(GIT_TAG_NAME)

promu:
	@GOOS=$(GOOS) \
	GOARCH=$(GOARCH) \
	$(GO) install github.com/prometheus/promu@v0.14.0
PROMU=$(shell go env GOPATH)/bin/promu

# Run go fmt against code
.PHONY: fmt
fmt:
	@find . -type f -name '*.go'| grep -v "/vendor/" | xargs gofmt -w -s

# Run mod tidy against code
.PHONY: tidy
tidy:
	@go mod tidy

# Run golang lint against code
.PHONY: lint
lint: golangci-lint
	@$(GOLANG_LINT) run \
      --timeout 30m \
      --disable-all \
      -E unused \
      -E ineffassign \
      -E goimports \
      -E gofmt \
      -E misspell \
      -E unparam \
      -E unconvert \
      -E govet \
      -E errcheck

# find or download golangci-lint
# download golangci-lint if necessary
golangci-lint:
ifeq (, $(shell which golangci-lint))
	@GOOS=$(GOOS) \
        GOARCH=$(GOARCH) \
        $(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.52.2
GOLANG_LINT=$(shell go env GOPATH)/bin/golangci-lint
else
GOLANG_LINT=$(shell which golangci-lint)
endif

.PHONY: all style format build test vet tarball docker promu
