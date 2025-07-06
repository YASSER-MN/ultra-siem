# 🛡️ Ultra SIEM - Development & Deployment Makefile
# 
# Available targets:
#   make help          - Show this help message
#   make dev           - Start development environment
#   make build         - Build all components
#   make test          - Run all tests
#   make lint          - Run linting and code quality checks
#   make security      - Run security scans
#   make benchmark     - Run performance benchmarks
#   make clean         - Clean build artifacts
#   make deploy        - Deploy to production

.PHONY: help build test clean dev lint security benchmark deploy docs

# Variables
RUST_VERSION := 1.75
GO_VERSION := 1.22
ZIG_VERSION := 0.11.0
DOCKER_REGISTRY := ghcr.io/ultra-siem
VERSION := $(shell git describe --tags --always --dirty)
BUILD_DATE := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
COMMIT_SHA := $(shell git rev-parse --short HEAD)

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

# Default target
help: ## Show this help message
	@echo "$(CYAN)🛡️  Ultra SIEM - Development Commands$(RESET)"
	@echo ""
	@echo "$(YELLOW)📋 Available Commands:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)🔧 Build Information:$(RESET)"
	@echo "  Version:    $(GREEN)$(VERSION)$(RESET)"
	@echo "  Build Date: $(GREEN)$(BUILD_DATE)$(RESET)"
	@echo "  Commit:     $(GREEN)$(COMMIT_SHA)$(RESET)"

# ==============================================================================
# 🚀 Development Commands
# ==============================================================================

dev: ## Start development environment
	@echo "$(CYAN)🚀 Starting Ultra SIEM development environment...$(RESET)"
	@docker-compose -f docker-compose.dev.yml up -d
	@echo "$(GREEN)✅ Development environment started$(RESET)"
	@echo "$(YELLOW)📊 Services available at:$(RESET)"
	@echo "  - Grafana:    http://localhost:3000"
	@echo "  - ClickHouse: http://localhost:8123"
	@echo "  - NATS:       http://localhost:8222"
	@echo "  - API:        http://localhost:8080"

dev-stop: ## Stop development environment
	@echo "$(CYAN)🛑 Stopping development environment...$(RESET)"
	@docker-compose -f docker-compose.dev.yml down
	@echo "$(GREEN)✅ Development environment stopped$(RESET)"

dev-logs: ## Show development environment logs
	@docker-compose -f docker-compose.dev.yml logs -f

dev-status: ## Show status of development services
	@docker-compose -f docker-compose.dev.yml ps

# ==============================================================================
# 🏗️ Build Commands
# ==============================================================================

build: build-rust build-go build-zig build-docker ## Build all components
	@echo "$(GREEN)✅ All components built successfully$(RESET)"

build-rust: ## Build Rust components
	@echo "$(CYAN)🦀 Building Rust core...$(RESET)"
	@cd rust-core && cargo build --release
	@echo "$(GREEN)✅ Rust core built$(RESET)"

build-go: ## Build Go services
	@echo "$(CYAN)🐹 Building Go services...$(RESET)"
	@cd go-services && go build -ldflags="-X main.version=$(VERSION) -X main.buildDate=$(BUILD_DATE) -X main.commitSHA=$(COMMIT_SHA)" -o bin/ultra-siem-bridge ./bridge
	@cd go-services && go build -ldflags="-X main.version=$(VERSION) -X main.buildDate=$(BUILD_DATE) -X main.commitSHA=$(COMMIT_SHA)" -o bin/ultra-siem-processor .
	@echo "$(GREEN)✅ Go services built$(RESET)"

build-zig: ## Build Zig query engine
	@echo "$(CYAN)⚡ Building Zig query engine...$(RESET)"
	@cd zig-query && zig build -Doptimize=ReleaseFast
	@echo "$(GREEN)✅ Zig query engine built$(RESET)"

build-docker: ## Build Docker images
	@echo "$(CYAN)🐳 Building Docker images...$(RESET)"
	@docker build -t $(DOCKER_REGISTRY)/rust-core:$(VERSION) ./rust-core
	@docker build -t $(DOCKER_REGISTRY)/rust-core:latest ./rust-core
	@docker build -t $(DOCKER_REGISTRY)/go-services:$(VERSION) ./go-services
	@docker build -t $(DOCKER_REGISTRY)/go-services:latest ./go-services
	@docker build -t $(DOCKER_REGISTRY)/zig-query:$(VERSION) ./zig-query
	@docker build -t $(DOCKER_REGISTRY)/zig-query:latest ./zig-query
	@echo "$(GREEN)✅ Docker images built$(RESET)"

build-cross: ## Build for multiple platforms
	@echo "$(CYAN)🌍 Building for multiple platforms...$(RESET)"
	@cd rust-core && cargo build --release --target x86_64-unknown-linux-gnu
	@cd rust-core && cargo build --release --target x86_64-pc-windows-gnu
	@cd rust-core && cargo build --release --target x86_64-apple-darwin
	@cd rust-core && cargo build --release --target aarch64-apple-darwin
	@echo "$(GREEN)✅ Cross-platform builds completed$(RESET)"

# ==============================================================================
# 🧪 Testing Commands
# ==============================================================================

test: test-rust test-go test-zig test-integration ## Run all tests
	@echo "$(GREEN)✅ All tests completed$(RESET)"

test-rust: ## Run Rust tests
	@echo "$(CYAN)🦀 Running Rust tests...$(RESET)"
	@cd rust-core && cargo test --all-features
	@echo "$(GREEN)✅ Rust tests passed$(RESET)"

test-go: ## Run Go tests
	@echo "$(CYAN)🐹 Running Go tests...$(RESET)"
	@cd go-services && go test -v -race -coverprofile=coverage.out ./...
	@echo "$(GREEN)✅ Go tests passed$(RESET)"

test-zig: ## Run Zig tests
	@echo "$(CYAN)⚡ Running Zig tests...$(RESET)"
	@cd zig-query && zig build test
	@echo "$(GREEN)✅ Zig tests passed$(RESET)"

test-integration: ## Run integration tests
	@echo "$(CYAN)🔗 Running integration tests...$(RESET)"
	@docker-compose -f docker-compose.test.yml up -d
	@sleep 30
	@python3 tests/integration/run_tests.py
	@docker-compose -f docker-compose.test.yml down
	@echo "$(GREEN)✅ Integration tests passed$(RESET)"

test-coverage: ## Generate test coverage reports
	@echo "$(CYAN)📊 Generating coverage reports...$(RESET)"
	@cd rust-core && cargo tarpaulin --out Html --output-dir ../reports/coverage/rust
	@cd go-services && go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out -o ../reports/coverage/go/coverage.html
	@echo "$(GREEN)✅ Coverage reports generated in reports/coverage/$(RESET)"

# ==============================================================================
# 🔍 Code Quality Commands
# ==============================================================================

lint: lint-rust lint-go lint-zig lint-docker ## Run all linting
	@echo "$(GREEN)✅ All linting completed$(RESET)"

lint-rust: ## Lint Rust code
	@echo "$(CYAN)🦀 Linting Rust code...$(RESET)"
	@cd rust-core && cargo fmt --check
	@cd rust-core && cargo clippy --all-targets --all-features -- -D warnings
	@echo "$(GREEN)✅ Rust linting passed$(RESET)"

lint-go: ## Lint Go code
	@echo "$(CYAN)🐹 Linting Go code...$(RESET)"
	@cd go-services && go fmt ./...
	@cd go-services && go vet ./...
	@cd go-services && golangci-lint run
	@echo "$(GREEN)✅ Go linting passed$(RESET)"

lint-zig: ## Lint Zig code
	@echo "$(CYAN)⚡ Linting Zig code...$(RESET)"
	@cd zig-query && zig fmt --check src/
	@echo "$(GREEN)✅ Zig linting passed$(RESET)"

lint-docker: ## Lint Dockerfiles
	@echo "$(CYAN)🐳 Linting Dockerfiles...$(RESET)"
	@hadolint rust-core/Dockerfile
	@hadolint go-services/Dockerfile
	@hadolint zig-query/Dockerfile
	@echo "$(GREEN)✅ Docker linting passed$(RESET)"

lint-fix: ## Auto-fix linting issues
	@echo "$(CYAN)🔧 Auto-fixing linting issues...$(RESET)"
	@cd rust-core && cargo fmt
	@cd go-services && go fmt ./...
	@cd zig-query && zig fmt src/
	@echo "$(GREEN)✅ Linting issues fixed$(RESET)"

# ==============================================================================
# 🔒 Security Commands
# ==============================================================================

security: security-audit security-scan security-deps ## Run all security checks
	@echo "$(GREEN)✅ All security checks completed$(RESET)"

security-audit: ## Run security audit
	@echo "$(CYAN)🔍 Running security audit...$(RESET)"
	@cd rust-core && cargo audit
	@cd go-services && govulncheck ./...
	@echo "$(GREEN)✅ Security audit passed$(RESET)"

security-scan: ## Run security scan with Semgrep
	@echo "$(CYAN)🛡️ Running security scan...$(RESET)"
	@semgrep --config=auto --json --output=reports/semgrep-results.json .
	@echo "$(GREEN)✅ Security scan completed$(RESET)"

security-deps: ## Check dependencies for vulnerabilities
	@echo "$(CYAN)📦 Checking dependencies...$(RESET)"
	@trivy fs --security-checks vuln .
	@echo "$(GREEN)✅ Dependency check completed$(RESET)"

security-secrets: ## Scan for secrets
	@echo "$(CYAN)🔐 Scanning for secrets...$(RESET)"
	@trufflehog filesystem --directory . --json > reports/secrets-scan.json
	@echo "$(GREEN)✅ Secrets scan completed$(RESET)"

# ==============================================================================
# ⚡ Performance Commands
# ==============================================================================

benchmark: benchmark-rust benchmark-go benchmark-load ## Run all benchmarks
	@echo "$(GREEN)✅ All benchmarks completed$(RESET)"

benchmark-rust: ## Run Rust benchmarks
	@echo "$(CYAN)🦀 Running Rust benchmarks...$(RESET)"
	@cd rust-core && cargo bench --features benchmark
	@echo "$(GREEN)✅ Rust benchmarks completed$(RESET)"

benchmark-go: ## Run Go benchmarks
	@echo "$(CYAN)🐹 Running Go benchmarks...$(RESET)"
	@cd go-services && go test -bench=. -benchmem ./...
	@echo "$(GREEN)✅ Go benchmarks completed$(RESET)"

benchmark-load: ## Run load testing
	@echo "$(CYAN)🚀 Running load tests...$(RESET)"
	@k6 run --out json=reports/loadtest-results.json scripts/load_test.js
	@echo "$(GREEN)✅ Load testing completed$(RESET)"

benchmark-memory: ## Profile memory usage
	@echo "$(CYAN)🧠 Profiling memory usage...$(RESET)"
	@docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.CPUPerc}}" > reports/memory-profile.txt
	@echo "$(GREEN)✅ Memory profiling completed$(RESET)"

# ==============================================================================
# 📚 Documentation Commands
# ==============================================================================

docs: ## Generate documentation
	@echo "$(CYAN)📚 Generating documentation...$(RESET)"
	@cd rust-core && cargo doc --no-deps
	@cd go-services && godoc -html > ../docs/go-api.html
	@echo "$(GREEN)✅ Documentation generated$(RESET)"

docs-serve: ## Serve documentation locally
	@echo "$(CYAN)📖 Serving documentation at http://localhost:8000...$(RESET)"
	@python3 -m http.server 8000 -d docs/

docs-api: ## Generate API documentation
	@echo "$(CYAN)🔌 Generating API documentation...$(RESET)"
	@swagger generate spec -o docs/api-spec.yaml
	@echo "$(GREEN)✅ API documentation generated$(RESET)"

# ==============================================================================
# 🚀 Deployment Commands
# ==============================================================================

deploy: deploy-build deploy-push deploy-k8s ## Deploy to production
	@echo "$(GREEN)✅ Deployment completed$(RESET)"

deploy-build: ## Build for deployment
	@echo "$(CYAN)🏗️ Building for deployment...$(RESET)"
	@$(MAKE) build-cross
	@$(MAKE) build-docker
	@echo "$(GREEN)✅ Build for deployment completed$(RESET)"

deploy-push: ## Push Docker images
	@echo "$(CYAN)📤 Pushing Docker images...$(RESET)"
	@docker push $(DOCKER_REGISTRY)/rust-core:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/rust-core:latest
	@docker push $(DOCKER_REGISTRY)/go-services:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/go-services:latest
	@docker push $(DOCKER_REGISTRY)/zig-query:$(VERSION)
	@docker push $(DOCKER_REGISTRY)/zig-query:latest
	@echo "$(GREEN)✅ Docker images pushed$(RESET)"

deploy-k8s: ## Deploy to Kubernetes
	@echo "$(CYAN)☸️ Deploying to Kubernetes...$(RESET)"
	@helm upgrade --install ultra-siem ./charts/ultra-siem \
		--set image.tag=$(VERSION) \
		--set global.version=$(VERSION)
	@echo "$(GREEN)✅ Kubernetes deployment completed$(RESET)"

deploy-staging: ## Deploy to staging environment
	@echo "$(CYAN)🎭 Deploying to staging...$(RESET)"
	@docker-compose -f docker-compose.staging.yml up -d
	@echo "$(GREEN)✅ Staging deployment completed$(RESET)"

# ==============================================================================
# 🧹 Cleanup Commands
# ==============================================================================

clean: clean-rust clean-go clean-zig clean-docker ## Clean all build artifacts
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"

clean-rust: ## Clean Rust build artifacts
	@echo "$(CYAN)🦀 Cleaning Rust artifacts...$(RESET)"
	@cd rust-core && cargo clean
	@echo "$(GREEN)✅ Rust artifacts cleaned$(RESET)"

clean-go: ## Clean Go build artifacts
	@echo "$(CYAN)🐹 Cleaning Go artifacts...$(RESET)"
	@cd go-services && go clean
	@rm -rf go-services/bin/
	@echo "$(GREEN)✅ Go artifacts cleaned$(RESET)"

clean-zig: ## Clean Zig build artifacts
	@echo "$(CYAN)⚡ Cleaning Zig artifacts...$(RESET)"
	@cd zig-query && rm -rf zig-cache/ zig-out/
	@echo "$(GREEN)✅ Zig artifacts cleaned$(RESET)"

clean-docker: ## Clean Docker images and containers
	@echo "$(CYAN)🐳 Cleaning Docker artifacts...$(RESET)"
	@docker system prune -f
	@docker image prune -f
	@echo "$(GREEN)✅ Docker artifacts cleaned$(RESET)"

clean-reports: ## Clean test and benchmark reports
	@echo "$(CYAN)📊 Cleaning reports...$(RESET)"
	@rm -rf reports/
	@mkdir -p reports/coverage/{rust,go} reports/benchmarks reports/security
	@echo "$(GREEN)✅ Reports cleaned$(RESET)"

# ==============================================================================
# 🛠️ Utility Commands
# ==============================================================================

setup: ## Setup development environment
	@echo "$(CYAN)🛠️ Setting up development environment...$(RESET)"
	@./scripts/setup-dev-environment.sh
	@echo "$(GREEN)✅ Development environment setup completed$(RESET)"

install-deps: ## Install all dependencies
	@echo "$(CYAN)📦 Installing dependencies...$(RESET)"
	@rustup update $(RUST_VERSION)
	@cd rust-core && cargo fetch
	@cd go-services && go mod download
	@echo "$(GREEN)✅ Dependencies installed$(RESET)"

update-deps: ## Update all dependencies
	@echo "$(CYAN)⬆️ Updating dependencies...$(RESET)"
	@cd rust-core && cargo update
	@cd go-services && go get -u ./...
	@echo "$(GREEN)✅ Dependencies updated$(RESET)"

version: ## Show version information
	@echo "$(CYAN)ℹ️ Version Information:$(RESET)"
	@echo "  Version:    $(GREEN)$(VERSION)$(RESET)"
	@echo "  Build Date: $(GREEN)$(BUILD_DATE)$(RESET)"
	@echo "  Commit:     $(GREEN)$(COMMIT_SHA)$(RESET)"
	@echo "  Rust:       $(GREEN)$(RUST_VERSION)$(RESET)"
	@echo "  Go:         $(GREEN)$(GO_VERSION)$(RESET)"
	@echo "  Zig:        $(GREEN)$(ZIG_VERSION)$(RESET)"

# ==============================================================================
# 📊 Monitoring Commands
# ==============================================================================

monitor: ## Monitor running services
	@echo "$(CYAN)📊 Monitoring Ultra SIEM services...$(RESET)"
	@watch -n 2 'docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"'

logs: ## Show service logs
	@echo "$(CYAN)📋 Showing service logs...$(RESET)"
	@docker-compose logs -f

health: ## Check service health
	@echo "$(CYAN)🏥 Checking service health...$(RESET)"
	@curl -s http://localhost:8123/ping && echo "✅ ClickHouse healthy"
	@curl -s http://localhost:3000/api/health && echo "✅ Grafana healthy"
	@curl -s http://localhost:8080/health && echo "✅ SIEM API healthy"
	@curl -s http://localhost:8222/varz && echo "✅ NATS healthy"

# ==============================================================================
# 🎭 Demo Commands
# ==============================================================================

demo: ## Start demo environment with sample data
	@echo "$(CYAN)🎭 Starting Ultra SIEM demo...$(RESET)"
	@docker-compose -f examples/docker-compose.example.yml up -d
	@echo "$(GREEN)✅ Demo environment started$(RESET)"
	@echo "$(YELLOW)📊 Demo services available at:$(RESET)"
	@echo "  - Demo App:   http://localhost:8090"
	@echo "  - Grafana:    http://localhost:3000 (admin/admin123)"
	@echo "  - ClickHouse: http://localhost:8123"

demo-stop: ## Stop demo environment
	@echo "$(CYAN)🛑 Stopping demo environment...$(RESET)"
	@docker-compose -f examples/docker-compose.example.yml down
	@echo "$(GREEN)✅ Demo environment stopped$(RESET)"

demo-logs: ## Show demo environment logs
	@docker-compose -f examples/docker-compose.example.yml logs -f

demo-reset: ## Reset demo environment (clean slate)
	@echo "$(CYAN)🔄 Resetting demo environment...$(RESET)"
	@docker-compose -f examples/docker-compose.example.yml down -v
	@$(MAKE) demo

# Create necessary directories
$(shell mkdir -p reports/coverage/{rust,go} reports/benchmarks reports/security examples/html)

# Default goal
.DEFAULT_GOAL := help 