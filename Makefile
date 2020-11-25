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
	#TODO: give output zero if all are healthy and 1 if all are not healthy

cluster-register-runners: ## register all the runners in the cluster as shared runner to the master
# TODO 1: Execute status and if master and runner status is both health only then attempt to register.
# For doing this, use the status code of the previous cluster-status target
# Otherwise spit out error saying "Master needs to be completely up and running before attempting to register runner"

# TODO 2: Add waiting graphic till the time we retrive the RUNNER_REGISTRATION_TOKEN, fetch gateway address, registering runner etc

#TODO 5: Add make target to parameterize Docker-compose file/overide hostname and port for gitlab-master

	@HOST_GATEWAY_IP=$$(docker inspect `docker ps --format '{{.Names}}' | grep -E 'gitlab-docker-sandbox.*master'` | jq -r '.[].NetworkSettings.Networks | .[].Gateway'); \
	echo "HOST_GATEWAY_IP: $$HOST_GATEWAY_IP"; \
	RUNNER_REGISTRATION_TOKEN=$$(docker-compose exec -T gitlab-master bash -c 'gitlab-rails runner -e production "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"' | tr -d '\r'); \
	echo "RUNNER_REGISTRATION_TOKEN = $$RUNNER_REGISTRATION_TOKEN"; \
	docker-compose exec -T gitlab-runner-host \
		gitlab-runner register \
		--non-interactive \
		--registration-token $$RUNNER_REGISTRATION_TOKEN \
		--description alpine \
		--url "http://gitlab.example.com:8000" \
		--clone-url "http://$$HOST_GATEWAY_IP:8000" \
		--executor docker \
		--docker-image alpine:stable

cluster-down: gitlab-cleanup ## take down cluster and remove containers
	@echo "Removing service containers and volumes"
	@docker-compose down -v --remove-orphans

cluster-logs: ## cluster logs
	docker-compose logs -f