.PHONY: help check build server pair token e2e swift-build swift-run clean

help:
	@echo "Targets:"
	@echo "  make check        - Run cargo check"
	@echo "  make build        - Build Rust workspace"
	@echo "  make server       - Run sigorad-server"
	@echo "  make pair         - Run sigora pair"
	@echo "  make token        - Run sigora token PROVIDER=github ACTION=repo.read RESOURCE=org/repo TYPE=bearer_token ALIAS=default"
	@echo "  make e2e          - Run Rust sigora/sigorad shell e2e cases"
	@echo "  make swift-build  - Build SigoraMenuBar Swift package"
	@echo "  make swift-run    - Run SigoraMenuBar Swift package"
	@echo "  make clean        - Clean Rust and Swift build artifacts"

check:
	cargo check

build:
	cargo build

server:
	cargo run -p sigorad-server

pair:
	cargo run -p sigora-cli -- pair

token:
	cargo run -p sigora-cli -- token --provider $(or $(PROVIDER),github) --action $(or $(ACTION),repo.read) --resource $(or $(RESOURCE),org/repo) $(if $(TYPE),--type $(TYPE),) $(if $(ALIAS),--alias $(ALIAS),)

e2e:
	bash scripts/e2e/run.sh

swift-build:
	cd apps/SigoraMenuBar && CLANG_MODULE_CACHE_PATH=$(CURDIR)/.swift-cache/ModuleCache SWIFTPM_MODULECACHE_OVERRIDE=$(CURDIR)/.swift-cache/ModuleCache swift build

swift-run:
	cd apps/SigoraMenuBar && CLANG_MODULE_CACHE_PATH=$(CURDIR)/.swift-cache/ModuleCache SWIFTPM_MODULECACHE_OVERRIDE=$(CURDIR)/.swift-cache/ModuleCache swift run

clean:
	cargo clean
	rm -rf .swift-cache
	rm -rf apps/SigoraMenuBar/.build
