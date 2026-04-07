GO ?= /usr/local/go/bin/go
GOFMT ?= /usr/local/go/bin/gofmt
LOCALBIN ?= $(CURDIR)/bin
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen

.PHONY: all
all: fmt test

.PHONY: controller-gen
controller-gen:
	@test -x "$(CONTROLLER_GEN)" || { \
		echo "installing controller-gen to $(LOCALBIN)"; \
		mkdir -p "$(LOCALBIN)"; \
		GOBIN="$(LOCALBIN)" $(GO) install sigs.k8s.io/controller-tools/cmd/controller-gen@v0.16.5; \
	}

.PHONY: fmt
fmt:
	find . -name '*.go' -print0 | xargs -0 $(GOFMT) -w

.PHONY: generate
generate: controller-gen
	$(CONTROLLER_GEN) object paths="./..."

.PHONY: manifests
manifests: controller-gen
	$(CONTROLLER_GEN) crd paths="./api/..." output:crd:artifacts:config=config/crd/bases

.PHONY: test
test:
	$(GO) test ./...

.PHONY: build
build:
	CGO_ENABLED=0 $(GO) build -o bin/data-protection-operator ./main.go
