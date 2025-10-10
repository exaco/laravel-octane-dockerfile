#!/usr/bin/make
# Makefile readme (en): <https://www.gnu.org/software/make/manual/html_node/index.html#SEC_Contents>

SHELL = /bin/bash
DC_RUN_ARGS = --env-file ./.env.production --profile app --profile administration -f compose.production.yaml
HOST_UID = $(shell if [ $$(id -u) -eq 0 ] && [ $$(id -g) -eq 0 ]; then echo 1000; else id -u; fi)
HOST_GID = $(shell if [ $$(id -u) -eq 0 ] && [ $$(id -g) -eq 0 ]; then echo 1000; else id -g; fi)

.PHONY: help up down stop shell\:app stop-all ps update build restart down-up images\:list images\:clean logs\:app logs containers\:health command\:app
.DEFAULT_GOAL: help

# This will output the help for each task. thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Show this help
	@printf "\033[33m%s:\033[0m\n" 'Available commands'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Up containers
	HOST_UID=${HOST_UID} HOST_GID=${HOST_GID} docker compose ${DC_RUN_ARGS} up -d --remove-orphans

logs: ## Tail all containers logs
	docker compose ${DC_RUN_ARGS} logs -f

logs\:app: ## Tail app container logs
	docker compose ${DC_RUN_ARGS} logs -f app

down: ## Stop and remove containers and networks
	docker compose ${DC_RUN_ARGS} down

stop: ## Stop containers
	docker compose ${DC_RUN_ARGS} stop

down\:with-volumes: ## Stop and remove containers and networks and remove volumes
	docker compose ${DC_RUN_ARGS} down -v

shell\:app: ## Start shell into app container
	docker compose ${DC_RUN_ARGS} exec app sh

command\:app: ## Run a command in the app container
	docker compose ${DC_RUN_ARGS} exec app sh -c "$(command)"

stop-all: ## Stop all containers
	docker stop $(shell docker ps -a -q)

ps: ## Containers status
	docker compose ${DC_RUN_ARGS} ps

build: ## Build images
	HOST_UID=${HOST_UID} HOST_GID=${HOST_GID} docker compose ${DC_RUN_ARGS} build

update: ## Update containers
	HOST_UID=${HOST_UID} HOST_GID=${HOST_GID} docker compose ${DC_RUN_ARGS} up -d --no-deps --build --remove-orphans

restart: ## Restart all containers
	HOST_UID=${HOST_UID} HOST_GID=${HOST_GID} docker compose ${DC_RUN_ARGS} restart

down-up: down up ## Down all containers, then up

images\:list: ## Sort Docker images by size
	docker images --format "{{.ID}}\t{{.Size}}\t{{.Repository}}" | sort -k 2 -h

images\:clean: ## Remove all dangling images and images not referenced by any container
	docker image prune -a

containers\:health: ## Check all containers health
	docker compose ${DC_RUN_ARGS} ps --format "table {{.Name}}\t{{.Service}}\t{{.Status}}"
