# 🛡️ Ultra SIEM - Development Makefile
# Multi-language, cross-platform SIEM development automation

.PHONY: help setup build test clean docker deploy

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Project configuration
PROJECT_NAME := ultra-siem
VERSION := $(shell git describe --tags --always --dirty)
BUILD_TIME := $(shell date +%Y-%m-%dT%H:%M:%S%z)
GIT_COMMIT := $(shell git rev-parse HEAD)

# Build flags
RUST_BUILD_FLAGS := --release
GO_BUILD_FLAGS := -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)"
ZIG_BUILD_FLAGS := -Doptimize=ReleaseFast

##@ General Commands

help: ## Display this help message
	@echo "$(BLUE)🛡️  Ultra SIEM Development Commands$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make $(GREEN)<target>$(RESET)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

version: ## Show version information
	@echo "$(BLUE)📋 Version Information$(RESET)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"

##@ Development Setup

setup: ## Set up development environment
	@echo "$(BLUE)🔧 Setting up development environment...$(RESET)"
	@./scripts/setup-dev-environment.sh
	@echo "$(GREEN)✅ Development environment ready!$(RESET)"

install-tools: ## Install development tools
	@echo "$(BLUE)🛠️  Installing development tools...$(RESET)"
	@command -v rustup >/dev/null || (echo "Installing Rust..." && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)
	@rustup component add clippy rustfmt
	@command -v go >/dev/null || echo "$(YELLOW)⚠️  Go not found. Please install Go 1.21+$(RESET)"
	@echo "$(GREEN)✅ Tools installed!$(RESET)"

deps: ## Install dependencies
	@echo "$(BLUE)📦 Installing dependencies...$(RESET)"
	@cd rust-core && cargo fetch
	@cd go-services && go mod download
	@echo "$(GREEN)✅ Dependencies installed!$(RESET)"

##@ Building

build: build-rust build-go build-zig ## Build all components
	@echo "$(GREEN)✅ All components built successfully!$(RESET)"

build-rust: ## Build Rust core engine
	@echo "$(BLUE)🦀 Building Rust core engine...$(RESET)"
	@cd rust-core && cargo build $(RUST_BUILD_FLAGS)
	@echo "$(GREEN)✅ Rust core engine built!$(RESET)"

build-go: ## Build Go services
	@echo "$(BLUE)🐹 Building Go services...$(RESET)"
	@cd go-services && go build $(GO_BUILD_FLAGS) -o ../bin/bridge ./bridge
	@cd go-services && go build $(GO_BUILD_FLAGS) -o ../bin/siem-processor ./processor
	@echo "$(GREEN)✅ Go services built!$(RESET)"

build-zig: ## Build Zig query engine
	@echo "$(BLUE)⚡ Building Zig query engine...$(RESET)"
	@cd zig-query && zig build $(ZIG_BUILD_FLAGS)
	@echo "$(GREEN)✅ Zig query engine built!$(RESET)"

##@ Testing

test: test-rust test-go test-zig test-integration ## Run all tests
	@echo "$(GREEN)✅ All tests completed!$(RESET)"

test-rust: ## Run Rust tests
	@echo "$(BLUE)🦀 Running Rust tests...$(RESET)"
	@cd rust-core && cargo test --verbose

test-go: ## Run Go tests
	@echo "$(BLUE)🐹 Running Go tests...$(RESET)"
	@cd go-services && go test -v -race ./...

test-zig: ## Run Zig tests
	@echo "$(BLUE)⚡ Running Zig tests...$(RESET)"
	@cd zig-query && zig test src/main.zig

test-integration: ## Run integration tests
	@echo "$(BLUE)🔗 Running integration tests...$(RESET)"
	@docker-compose -f docker-compose.test.yml up --build -d
	@sleep 30
	@curl -f http://localhost:8123/ping || (echo "$(RED)❌ ClickHouse not responding$(RESET)" && exit 1)
	@curl -f http://localhost:3000/api/health || (echo "$(RED)❌ Grafana not responding$(RESET)" && exit 1)
	@docker-compose -f docker-compose.test.yml down -v
	@echo "$(GREEN)✅ Integration tests passed!$(RESET)"

test-coverage: ## Run tests with coverage
	@echo "$(BLUE)📊 Running tests with coverage...$(RESET)"
	@cd rust-core && cargo tarpaulin --out html --output-dir ../coverage/rust
	@cd go-services && go test -coverprofile=../coverage/go/coverage.out ./...
	@echo "$(GREEN)✅ Coverage reports generated in coverage/$(RESET)"

##@ Code Quality

lint: lint-rust lint-go lint-zig ## Run all linters
	@echo "$(GREEN)✅ All linting completed!$(RESET)"

lint-rust: ## Run Rust linting
	@echo "$(BLUE)🦀 Running Rust linting...$(RESET)"
	@cd rust-core && cargo clippy -- -D warnings
	@cd rust-core && cargo fmt --check

lint-go: ## Run Go linting
	@echo "$(BLUE)🐹 Running Go linting...$(RESET)"
	@cd go-services && go vet ./...
	@cd go-services && go fmt ./...

lint-zig: ## Run Zig linting
	@echo "$(BLUE)⚡ Running Zig linting...$(RESET)"
	@cd zig-query && zig fmt --check src/

fix: ## Fix code formatting
	@echo "$(BLUE)🎨 Fixing code formatting...$(RESET)"
	@cd rust-core && cargo fmt
	@cd go-services && go fmt ./...
	@cd zig-query && zig fmt src/
	@echo "$(GREEN)✅ Code formatting fixed!$(RESET)"

security-check: ## Run security checks
	@echo "$(BLUE)🔒 Running security checks...$(RESET)"
	@cd rust-core && cargo audit
	@cd go-services && go list -json -m all | nancy sleuth
	@docker run --rm -v $(PWD):/src returntocorp/semgrep --config=auto /src
	@echo "$(GREEN)✅ Security checks completed!$(RESET)"

##@ Docker Operations

docker: docker-build ## Build all Docker images
	@echo "$(GREEN)✅ All Docker images built!$(RESET)"

docker-build: ## Build Docker images
	@echo "$(BLUE)🐳 Building Docker images...$(RESET)"
	@docker-compose -f docker-compose.simple.yml build
	@echo "$(GREEN)✅ Docker images built!$(RESET)"

docker-up: ## Start all services with Docker
	@echo "$(BLUE)🚀 Starting Ultra SIEM services...$(RESET)"
	@docker-compose -f docker-compose.simple.yml up -d
	@echo "$(GREEN)✅ Services started!$(RESET)"
	@echo "$(BLUE)🌐 Access URLs:$(RESET)"
	@echo "  • Grafana: http://localhost:3000 (admin/admin)"
	@echo "  • ClickHouse: http://localhost:8123"
	@echo "  • NATS: http://localhost:8222"

docker-down: ## Stop all services
	@echo "$(BLUE)🛑 Stopping Ultra SIEM services...$(RESET)"
	@docker-compose -f docker-compose.simple.yml down -v
	@echo "$(GREEN)✅ Services stopped!$(RESET)"

docker-logs: ## Show service logs
	@docker-compose -f docker-compose.simple.yml logs -f

docker-clean: ## Clean Docker resources
	@echo "$(BLUE)🧹 Cleaning Docker resources...$(RESET)"
	@docker-compose -f docker-compose.simple.yml down -v --remove-orphans
	@docker system prune -f
	@echo "$(GREEN)✅ Docker resources cleaned!$(RESET)"

##@ Development

dev: docker-up ## Start development environment
	@echo "$(BLUE)💻 Development environment ready!$(RESET)"
	@echo "$(YELLOW)📝 Watching for file changes...$(RESET)"

dev-rust: ## Start Rust development with hot reload
	@echo "$(BLUE)🦀 Starting Rust development...$(RESET)"
	@cd rust-core && cargo watch -x 'run'

dev-go: ## Start Go development with hot reload
	@echo "$(BLUE)🐹 Starting Go development...$(RESET)"
	@cd go-services && air -c .air.toml

benchmark: ## Run performance benchmarks
	@echo "$(BLUE)⚡ Running performance benchmarks...$(RESET)"
	@cd rust-core && cargo bench
	@cd go-services && go test -bench=. ./...
	@echo "$(GREEN)✅ Benchmarks completed!$(RESET)"

profile: ## Profile application performance
	@echo "$(BLUE)📊 Profiling application performance...$(RESET)"
	@cd rust-core && cargo flamegraph --bin siem-core
	@echo "$(GREEN)✅ Profiling completed! Check flamegraph.svg$(RESET)"

##@ Database Operations

db-setup: ## Set up database schema
	@echo "$(BLUE)🗄️  Setting up database schema...$(RESET)"
	@./scripts/setup-database.sh
	@echo "$(GREEN)✅ Database schema ready!$(RESET)"

db-reset: ## Reset database to clean state
	@echo "$(BLUE)🔄 Resetting database...$(RESET)"
	@docker-compose -f docker-compose.simple.yml exec clickhouse clickhouse-client --query "DROP DATABASE IF EXISTS siem"
	@make db-setup
	@echo "$(GREEN)✅ Database reset complete!$(RESET)"

db-backup: ## Backup database
	@echo "$(BLUE)💾 Creating database backup...$(RESET)"
	@mkdir -p backups
	@docker-compose -f docker-compose.simple.yml exec clickhouse clickhouse-client --query "BACKUP DATABASE siem TO 'backups/siem_$(shell date +%Y%m%d_%H%M%S).zip'"
	@echo "$(GREEN)✅ Database backup created!$(RESET)"

##@ Deployment

deploy-local: docker-up db-setup ## Deploy locally for testing
	@echo "$(GREEN)🎉 Ultra SIEM deployed locally!$(RESET)"

deploy-staging: ## Deploy to staging environment
	@echo "$(BLUE)🚀 Deploying to staging...$(RESET)"
	@./scripts/deploy-staging.sh
	@echo "$(GREEN)✅ Deployed to staging!$(RESET)"

deploy-prod: ## Deploy to production
	@echo "$(BLUE)🚀 Deploying to production...$(RESET)"
	@./scripts/deploy-production.sh
	@echo "$(GREEN)✅ Deployed to production!$(RESET)"

##@ Utilities

clean: ## Clean build artifacts
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(RESET)"
	@cd rust-core && cargo clean
	@cd go-services && go clean -cache -modcache -testcache
	@cd zig-query && rm -rf zig-cache zig-out
	@rm -rf bin/ coverage/ dist/
	@echo "$(GREEN)✅ Build artifacts cleaned!$(RESET)"

docs: ## Generate documentation
	@echo "$(BLUE)📚 Generating documentation...$(RESET)"
	@cd rust-core && cargo doc --no-deps --open
	@cd go-services && godoc -http=:6060 &
	@echo "$(GREEN)✅ Documentation generated!$(RESET)"

release: ## Prepare release
	@echo "$(BLUE)🎁 Preparing release...$(RESET)"
	@./scripts/prepare-release.sh $(VERSION)
	@echo "$(GREEN)✅ Release $(VERSION) prepared!$(RESET)"

status: ## Show system status
	@echo "$(BLUE)📊 Ultra SIEM System Status$(RESET)"
	@echo ""
	@echo "$(BLUE)🐳 Docker Services:$(RESET)"
	@docker-compose -f docker-compose.simple.yml ps 2>/dev/null || echo "  No services running"
	@echo ""
	@echo "$(BLUE)🌐 Service Health:$(RESET)"
	@curl -s http://localhost:8123/ping >/dev/null && echo "  ✅ ClickHouse: Healthy" || echo "  ❌ ClickHouse: Down"
	@curl -s http://localhost:3000/api/health >/dev/null && echo "  ✅ Grafana: Healthy" || echo "  ❌ Grafana: Down"
	@curl -s http://localhost:8222/varz >/dev/null && echo "  ✅ NATS: Healthy" || echo "  ❌ NATS: Down" 