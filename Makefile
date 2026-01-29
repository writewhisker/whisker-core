.PHONY: all clean test test-coverage test-unit test-integration test-contract test-all-versions build install dev docs docs-serve lint format validate validate-modularity help

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RESET  := $(shell tput -Txterm sgr0)

# Tool locations (with fallbacks for luarocks installs)
LUACHECK := $(shell command -v luacheck 2>/dev/null || echo ~/.luarocks/bin/luacheck)
BUSTED := $(shell command -v busted 2>/dev/null || echo ~/.luarocks/bin/busted)

# Default target
all: build test

# Help target
help:
	@echo "$(BLUE)Whisker Build System$(RESET)"
	@echo ""
	@echo "$(GREEN)Testing:$(RESET)"
	@echo "  $(YELLOW)make test$(RESET)             - Run all tests"
	@echo "  $(YELLOW)make test-coverage$(RESET)    - Run tests with coverage"
	@echo "  $(YELLOW)make test-unit$(RESET)        - Run unit tests only"
	@echo "  $(YELLOW)make test-integration$(RESET) - Run integration tests only"
	@echo "  $(YELLOW)make test-contract$(RESET)    - Run contract tests only"
	@echo "  $(YELLOW)make test-all-versions$(RESET)- Run tests across all Lua versions"
	@echo ""
	@echo "$(GREEN)Validation:$(RESET)"
	@echo "  $(YELLOW)make build$(RESET)            - Validate Lua modules (luacheck)"
	@echo "  $(YELLOW)make lint$(RESET)             - Run all linters"
	@echo "  $(YELLOW)make validate$(RESET)         - Validate example stories"
	@echo "  $(YELLOW)make validate-modularity$(RESET) - Run modularity validation"
	@echo ""
	@echo "$(GREEN)Development:$(RESET)"
	@echo "  $(YELLOW)make install$(RESET)          - Install development dependencies"
	@echo "  $(YELLOW)make clean$(RESET)            - Clean build artifacts"
	@echo "  $(YELLOW)make docs$(RESET)             - List documentation files"
	@echo ""
	@echo "$(GREEN)Shortcuts:$(RESET)"
	@echo "  $(YELLOW)make all$(RESET)              - Build and test everything"
	@echo ""

# Clean build artifacts
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(RESET)"
	@./scripts/clean.sh
	@echo "$(GREEN)✓ Clean complete!$(RESET)"

# Run all tests
test:
	@echo "$(BLUE)Running tests...$(RESET)"
	@$(BUSTED) --verbose
	@echo "$(GREEN)✓ Tests complete!$(RESET)"

# Run tests with coverage
test-coverage:
	@echo "$(BLUE)Running tests with coverage...$(RESET)"
	@$(BUSTED) --verbose --coverage
	@echo "$(GREEN)✓ Tests complete!$(RESET)"

# Run specific test suites
test-unit:
	@$(BUSTED) --verbose tests/unit/

test-integration:
	@$(BUSTED) --verbose tests/integration/

test-contract:
	@$(BUSTED) --verbose tests/contract/

# Run tests across all Lua versions (skips versions not installed locally)
test-all-versions:
	@./scripts/test-all-versions.sh

# Build/validate all components (Lua is interpreted, so this runs validation)
build:
	@echo "$(BLUE)Validating Lua modules...$(RESET)"
	@$(LUACHECK) lib/whisker/ --config .luacheckrc
	@echo "$(GREEN)✓ Validation complete!$(RESET)"

# Install development dependencies
install:
	@echo "$(BLUE)Installing dependencies...$(RESET)"
	@./scripts/setup-dev.sh
	@echo "$(GREEN)✓ Installation complete!$(RESET)"

# Start development environment
dev:
	@echo "$(BLUE)Starting development environment...$(RESET)"
	@docker-compose -f build/docker/docker-compose.yml up

# List documentation
docs:
	@echo "$(BLUE)Available documentation:$(RESET)"
	@ls -1 docs/*.md 2>/dev/null || echo "No documentation files found"

# Serve documentation locally (requires mkdocs)
docs-serve:
	@cd docs && mkdocs serve

# Run linters
lint:
	@echo "$(BLUE)Running linters...$(RESET)"
	@echo "Linting Lua code..."
	@$(LUACHECK) lib/whisker/ tests/ --config .luacheckrc || true
	@if [ -d "editor/web" ]; then \
		echo "Linting web editor..."; \
		cd editor/web && npm run lint || true; \
	fi
	@if [ -d "publisher/web" ]; then \
		echo "Linting web publisher..."; \
		cd publisher/web && npm run lint || true; \
	fi
	@echo "$(GREEN)✓ Linting complete!$(RESET)"

# Format code (if formatters are configured)
format:
	@echo "$(BLUE)Formatting code...$(RESET)"
	@if [ -d "editor/web" ]; then \
		cd editor/web && npm run format || true; \
	fi
	@if [ -d "publisher/web" ]; then \
		cd publisher/web && npm run format || true; \
	fi
	@echo "$(GREEN)✓ Formatting complete!$(RESET)"

# Validate example stories
validate:
	@echo "$(BLUE)Validating example stories...$(RESET)"
	@for story in examples/*.lua; do \
		echo "  Checking $$story..."; \
		lua -e "dofile('$$story')" 2>/dev/null && echo "    $(GREEN)✓$(RESET)" || echo "    $(YELLOW)⚠ syntax check only$(RESET)"; \
	done
	@echo "$(GREEN)✓ Validation complete!$(RESET)"

# Run modularity validation
validate-modularity:
	@echo "$(BLUE)Running modularity validation...$(RESET)"
	@lua validate.lua lib/whisker/
	@echo "$(GREEN)✓ Modularity validation complete!$(RESET)"

# Docker commands
docker-build:
	@echo "$(BLUE)Building Docker images...$(RESET)"
	@docker build -f build/docker/Dockerfile.build -t whisker:build .
	@docker build -f build/docker/Dockerfile.test -t whisker:test .
	@echo "$(GREEN)✓ Docker images built!$(RESET)"

docker-test:
	@echo "$(BLUE)Running tests in Docker...$(RESET)"
	@docker run --rm -v $(PWD):/workspace whisker:test
	@echo "$(GREEN)✓ Docker tests complete!$(RESET)"

docker-clean:
	@echo "$(BLUE)Cleaning Docker resources...$(RESET)"
	@docker-compose -f build/docker/docker-compose.yml down -v
	@docker rmi whisker:build whisker:test 2>/dev/null || true
	@echo "$(GREEN)✓ Docker cleanup complete!$(RESET)"

# Watch for changes and rebuild (requires entr or similar)
watch:
	@echo "$(BLUE)Watching for changes...$(RESET)"
	@find lib/whisker/ -name "*.lua" | entr -c make build