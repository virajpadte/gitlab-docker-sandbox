# VARIABLES:
SHARED_RUNNER_REGISTRATION_TOKEN := "QwERTy1234"

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

up: gitlab-cleanup traefik-config ## deploy cluster
	@docker-compose up -d

status: ## check readiness of the containers in the cluster
	@docker inspect `docker ps --format '{{.Names}}' | grep 'gitlab-docker-sandbox'` | jq -r '.[] | {"ServiceName":.Config.Labels."com.docker.compose.service", "Status":.State.Health.Status}'
#TODO: give output zero if all are healthy and 1 if all are not healthy

register-runners: ## register all the runners in the cluster as shared runner to the master
# TODO 1: Execute status and if master and runner status is both health only then attempt to register.
# For doing this, use the status code of the previous status target
# Otherwise spit out error saying "Master needs to be completely up and running before attempting to register runner"

# TODO 2: Add waiting graphic till the time we retrive the RUNNER_REGISTRATION_TOKEN, fetch gateway address, registering runner etc

#TODO 5: Add make target to parameterize Docker-compose file/overide hostname and port for gitlab-master and master root password

	@HOST_GATEWAY_IP=$$(docker inspect `docker ps --format '{{.Names}}' | grep -E 'gitlab-docker-sandbox.*master'` | jq -r '.[].NetworkSettings.Networks | .[].Gateway'); \
	echo "HOST_GATEWAY_IP: $$HOST_GATEWAY_IP"; \
	docker-compose exec -T gitlab-runner-host \
		gitlab-runner register \
		--non-interactive \
		--registration-token $(SHARED_RUNNER_REGISTRATION_TOKEN) \
		--description alpine \
		--url "http://gitlab.example.com:8000" \
		--clone-url "http://$$HOST_GATEWAY_IP:8000" \
		--executor docker \
		--docker-image alpine:stable

clean-runners: ## Unregister all runners from gitlab-master
	@docker-compose exec -T gitlab-runner-host \
		gitlab-runner unregister \
		--all-runners

down: gitlab-cleanup ## take down cluster and remove containers
	@echo "Removing service containers and volumes"
	@docker-compose down -v --remove-orphans

logs: ## cluster logs
	docker-compose logs -f