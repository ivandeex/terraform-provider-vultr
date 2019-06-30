.PHONY: all-release build clean fmt fmt-go fmt-terraform lint lint-ci lint-go lint-terraform release setup-tools test vendor vendor-status vet

ARCH ?= amd64
PLATFORM ?= linux
ALL_PLATFORMS := darwin linux windows
BIN := terraform-provider-vultr
PKG := github.com/squat/$(BIN)
BUILD_IMAGE ?= golang:1.10.0-alpine
# `go list ./...` takes too long in the module mode, let's use `find` instead.
TEST ?= $$(find . -name '*.go' | grep -v ./vendor | xargs -L1 dirname | sort -u)
GOFMT_FILES ?= $$(find . -name '*.go' | grep -v ./vendor)
SRC := $(shell find . -type f -name '*.go' -not -path "./vendor/*")
TERRAFORMFMT_FILES ?= examples
TESTARGS ?=
TAG := $(shell git describe --abbrev=0 --tags HEAD 2>/dev/null)
COMMIT := $(shell git rev-parse HEAD)
VERSION := $(COMMIT)
ifneq ($(TAG),)
    ifeq ($(COMMIT), $(shell git rev-list -n1 $(TAG)))
        VERSION := $(TAG)
    endif
endif
DIRTY := $(shell test -z "$$(git diff --shortstat 2>/dev/null)" || echo -dirty)
VERSION := $(VERSION)$(DIRTY)

default: build

build:
	go install

all-release: $(addprefix release-, $(ALL_PLATFORMS))

release-%:
	@$(MAKE) --no-print-directory ARCH=$(ARCH) PLATFORM=$* release

release: bin/$(BIN)_$(VERSION)_$(PLATFORM)_$(ARCH).tar.gz.asc

bin/$(PLATFORM)/$(ARCH):
	@mkdir -p bin/$(PLATFORM)/$(ARCH)

bin/$(BIN)_$(VERSION)_$(PLATFORM)_$(ARCH).tar.gz.asc: bin/$(BIN)_$(VERSION)_$(PLATFORM)_$(ARCH).tar.gz
	@cd bin && gpg --armor --detach-sign $(<F)

bin/$(BIN)_$(VERSION)_$(PLATFORM)_$(ARCH).tar.gz: bin/$(PLATFORM)/$(ARCH)/$(BIN)_$(VERSION)
	@tar -czf $@ -C $(<D) $(<F)

bin/$(PLATFORM)/$(ARCH)/$(BIN)_$(VERSION): $(SRC) glide.yaml bin/$(PLATFORM)/$(ARCH)
	@echo "building: $@"
	@docker run --rm \
	    -u $$(id -u):$$(id -g) \
	    -v $$(pwd):/go/src/$(PKG) \
	    -v $$(pwd)/bin/$(PLATFORM)/$(ARCH):/go/bin \
	    -w /go/src/$(PKG) \
	    $(BUILD_IMAGE) \
	    /bin/sh -c " \
	        GOARCH=$(ARCH) \
	        GOOS=$(PLATFORM) \
		CGO_ENABLED=0 \
		go build -o /go/bin/$(BIN)_$(VERSION) \
	    "

fmt: fmt-go fmt-terraform

fmt-go:
	gofmt -w -s $(GOFMT_FILES)

fmt-terraform:
	terraform fmt $(TERRAFORMFMT_FILES)

lint: lint-go lint-terraform lint-ci

lint-go:
	@echo 'golint $(TEST)'
	@lint_res=$$(golint $(TEST)); if [ -n "$$lint_res" ]; then \
		echo ""; \
		echo "Golint found style issues. Please check the reported issues"; \
		echo "and fix them if necessary before submitting the code for review:"; \
		echo "$$lint_res"; \
		exit 1; \
	fi
	@echo 'gofmt -d -s $(GOFMT_FILES)'
	@fmt_res=$$(gofmt -d -s $(GOFMT_FILES)); if [ -n "$$fmt_res" ]; then \
		echo ""; \
		echo "Gofmt found style issues. Please check the reported issues"; \
		echo "and fix them if necessary before submitting the code for review:"; \
		echo "$$fmt_res"; \
		exit 1; \
	fi

lint-terraform:
	@echo "terraform fmt --check=true $(TERRAFORMFMT_FILES)"
	@lint_res=$$(terraform fmt --check=true $(TERRAFORMFMT_FILES)); if [ -n "$$lint_res" ]; then \
		echo ""; \
		echo "Terraform fmt found style issues. Please check the reported issues"; \
		echo "and fix them if necessary before submitting the code for review:"; \
		echo "$$lint_res"; \
		exit 1; \
	fi

lint-ci:
	# TODO: fix all golangci-lint warnings!!! (workaround for now)
	golangci-lint run --deadline=10m $(TEST) || true

test: vet lint
	go test -i $(TEST) || exit 1
	go test $(TESTARGS) -timeout=30s -parallel=4 $(TEST)

vendor:
	@glide install -v
	@glide-vc --only-code --no-tests

vendor-status:
	@glide list

vet:
	@echo 'go vet $(TEST)'
	@go vet $(TEST); if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "Vet found suspicious constructs. Please check the reported constructs"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi

GOLANGCI_LINT_VER := 1.17.1
GOBIN := $(shell go env GOPATH)/bin

setup-tools:
	# we want that `go get` install utilities, but in the module mode its
	# behaviour is different; actually, `go get` would rather modify the
	# local `go.mod`, so let's disable modules here.
	GO111MODULE=off go get -u golang.org/x/lint/golint
	GO111MODULE=off go get -u golang.org/x/tools/cmd/goimports
	GO111MODULE=off go get -u github.com/hashicorp/terraform

	# golangci-lint takes pretty long to build
	# as an optimization, let's just download the binaries
	curl -sL "https://github.com/golangci/golangci-lint/releases/download/v$(GOLANGCI_LINT_VER)/golangci-lint-$(GOLANGCI_LINT_VER)-linux-amd64.tar.gz" | tar -xzf - -C $(GOBIN) --strip-components=1 "golangci-lint-$(GOLANGCI_LINT_VER)-linux-amd64/golangci-lint"

clean:
	@rm -rf bin ./terraform-provider-vultr
