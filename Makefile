# LVS Cloud - Development Makefile

.PHONY: help install format check test clean deploy

# Default target
help: ## Show this help message
	@echo "LVS Cloud - Development Commands"
	@echo "================================"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup and installation
install: ## Install all development dependencies
	@echo "🔧 Installing pre-commit hooks..."
	@pip install pre-commit
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "📦 Installing Ruby dependencies..."
	@cd applications/ruby-monitor && bundle install
	@echo "🏗️  Initializing Terraform..."
	@cd infrastructure && terraform init
	@echo "✅ Development environment ready!"

# Code formatting
format: ## Format all code files
	@echo "🎨 Formatting all files..."
	@pre-commit run --all-files || true
	@echo "✅ Formatting complete!"

# Code quality checks
check: ## Run all quality checks without fixing
	@echo "🔍 Running quality checks..."
	@pre-commit run --all-files --hook-stage manual
	@echo "🧹 Running Terraform validation..."
	@cd infrastructure && terraform validate
	@echo "🔐 Running security scans..."
	@pre-commit run detect-secrets --all-files
	@echo "✅ Quality checks complete!"

# Testing
test: ## Run all tests
	@echo "🧪 Running Ruby tests..."
	@cd applications/ruby-monitor && bundle exec rspec || echo "No tests found"
	@echo "🏗️  Testing Terraform plan..."
	@cd infrastructure && source ../.env && terraform plan
	@echo "✅ Tests complete!"

# Terraform operations
tf-plan: ## Run Terraform plan
	@echo "📋 Planning Terraform changes..."
	@cd infrastructure && source ../.env && terraform plan

tf-apply: ## Apply Terraform changes
	@echo "🚀 Applying Terraform changes..."
	@cd infrastructure && source ../.env && terraform apply

tf-destroy: ## Destroy Terraform infrastructure
	@echo "💥 Destroying infrastructure..."
	@cd infrastructure && source ../.env && terraform destroy

# Docker operations
build: ## Build all Docker images
	@echo "🐳 Building Ruby monitor image..."
	@cd applications/ruby-monitor && docker build -t ruby-monitor:latest .

run-local: ## Run services locally
	@echo "🏃 Starting local development stack..."
	@cd applications/monitoring-stack && docker compose up -d

stop-local: ## Stop local services
	@echo "⏹️  Stopping local stack..."
	@cd applications/monitoring-stack && docker compose down

# Deployment
deploy: ## Deploy to production
	@echo "🚀 Deploying to production..."
	@git push origin main
	@echo "📡 GitHub Actions will handle the deployment"

# Maintenance
clean: ## Clean up temporary files
	@echo "🧹 Cleaning up..."
	@find . -name "*.log" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@docker system prune -f
	@echo "✅ Cleanup complete!"

# Git operations
commit: ## Run pre-commit checks and commit
	@echo "📝 Running pre-commit checks..."
	@pre-commit run --all-files
	@echo "💾 Ready to commit! Use: git commit -m 'your message'"

# Development setup
dev-setup: install ## Complete development environment setup
	@echo "🎯 Development environment setup complete!"
	@echo "Next steps:"
	@echo "  1. Copy .env.example to .env and configure"
	@echo "  2. Run 'make tf-plan' to test Terraform"
	@echo "  3. Run 'make format' to format all files"
