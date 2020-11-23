# HELP
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help



# DOCKER TASKS

traefik-config: ## generate SSL certs for traefik
	@cd traefik && ./mkcerts.sh

gitlab-cleanup: ## cleanup all gitlab configurations
	@rm -Rf gitlab/master/config/* || True
	@rm -Rf gitlab/runner/config/* || True
	@rm -Rf traefik/config/* || True
	@rm -Rf traefik/certs/* || True

cluster-up: gitlab-cleanup traefik-config ## deploy cluster
	@docker-compose up -d

cluster-status: ## check readiness of the containers in the cluster
	@docker inspect `docker ps --format '{{.Names}}' | grep 'gitlab-docker-sandbox'` | jq '.[] | {"ContainerName":.Name, "Status":.State.Health.Status}'

cluster-down: gitlab-cleanup ## take down cluster and remove containers
	@echo "Removing service containers and volumes"
	@docker-compose down -v --remove-orphans

cluster-logs: ## cluster logs
	docker-compose logs -f