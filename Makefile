.PHONY: build clean dist fmt fmt-go fmt-terraform lint lint-ci lint-go lint-terraform lint-ci release setup-tools test vendor vendor-status vet

# `go list ./...` takes too long in the module mode, let's use `find` instead.
TEST ?= $$(find . -name '*.go' | grep -v ./vendor | xargs -L1 dirname | sort -u)
GOFMT_FILES ?= $$(find . -name '*.go' | grep -v ./vendor)
TERRAFORMFMT_FILES ?= examples
TESTARGS ?=

default: build

build:
	go install

dist:
	goreleaser --rm-dist --skip-publish

release:
	goreleaser --rm-dist

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
	GO111MODULE=on go mod tidy
	GO111MODULE=on go mod vendor

vet:
	@echo 'go vet $(TEST)'
	@go vet $(TEST); if [ $$? -eq 1 ]; then \
		echo ""; \
		echo "Vet found suspicious constructs. Please check the reported constructs"; \
		echo "and fix them if necessary before submitting the code for review."; \
		exit 1; \
	fi

GORELEASER_VER := 0.110.0
GOLANGCI_LINT_VER := 1.17.1
GOBIN := $(shell go env GOPATH)/bin

setup-tools:
	# we want that `go get` install utilities, but in the module mode its
	# behaviour is different; actually, `go get` would rather modify the
	# local `go.mod`, so let's disable modules here.
	GO111MODULE=off go get -u golang.org/x/lint/golint
	GO111MODULE=off go get -u golang.org/x/tools/cmd/goimports
	GO111MODULE=off go get -u github.com/hashicorp/terraform

	# goreleaser and golangci-lint take pretty long to build
	# as an optimization, let's just download the binaries
	curl -sL "https://github.com/goreleaser/goreleaser/releases/download/v$(GORELEASER_VER)/goreleaser_Linux_x86_64.tar.gz" | tar -xzf - -C $(GOBIN) goreleaser
	curl -sL "https://github.com/golangci/golangci-lint/releases/download/v$(GOLANGCI_LINT_VER)/golangci-lint-$(GOLANGCI_LINT_VER)-linux-amd64.tar.gz" | tar -xzf - -C $(GOBIN) --strip-components=1 "golangci-lint-$(GOLANGCI_LINT_VER)-linux-amd64/golangci-lint"

clean:
	@rm -rf bin dist ./terraform-provider-vultr
