.PHONY: build run dev docker-build docker-run clean test help

# Variables
APP_NAME := k6-dashboard
DOCKER_IMAGE := goormgb/k6-dashboard
VERSION := 1.0.0

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development
dev: ## Run in development mode (hot reload with air)
	@which air > /dev/null || go install github.com/air-verse/air@latest
	air

run: ## Run the application locally
	go run .

build: ## Build the binary
	go build -o bin/$(APP_NAME) .

# Docker
docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE):$(VERSION) -t $(DOCKER_IMAGE):latest .

docker-run: ## Run with Docker Compose
	docker-compose up -d

docker-stop: ## Stop Docker Compose
	docker-compose down

docker-rebuild: ## Rebuild and restart (down + build + up)
	docker-compose down && docker-compose build --no-cache && docker-compose up -d

docker-logs: ## View Docker logs
	docker-compose logs -f k6-dashboard

# Testing
test-smoke: ## Run smoke test against dev
	k6 run -e TARGET_URL=https://dev.goormgb.com -e VUS=5 -e DURATION=1m scripts/smoke.js

test-load: ## Run load test against dev
	k6 run -e TARGET_URL=https://dev.goormgb.com -e VUS=50 -e DURATION=5m scripts/load.js

test-stress: ## Run stress test against dev
	k6 run -e TARGET_URL=https://dev.goormgb.com -e VUS=200 scripts/stress.js

test-spike: ## Run spike test against dev (Auto Scaling verification)
	k6 run -e TARGET_URL=https://dev.goormgb.com -e VUS=300 scripts/spike.js

test-soak: ## Run soak test against dev (30 minutes)
	k6 run -e TARGET_URL=https://dev.goormgb.com -e VUS=50 -e DURATION=30m scripts/soak.js

# Utilities
clean: ## Clean build artifacts
	rm -rf bin/
	rm -rf tmp/

deps: ## Install dependencies
	go mod tidy
	go mod download

lint: ## Run linter
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	golangci-lint run

# k6 specific
k6-install: ## Install k6 locally (macOS)
	brew install k6

k6-version: ## Show k6 version
	k6 version
