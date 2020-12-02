# VARIABLES:

# ADMIN USER:
ADMIN_USER_PASSWORD := Test_123@
RANDOM_ID := $(shell bash -c 'echo $$RANDOM')

# SANDBOX USER:
SANDBOX_USERNAME:= user1
SANDBOX_USER_PASSWORD := Test_123@

#CONFIGURATION:
SHARED_RUNNER_REGISTRATION_TOKEN := QwERTy1234

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
	@echo "Checking service status..."
	@docker inspect `docker ps --format '{{.Names}}' | grep 'gitlab-docker-sandbox'` | jq -r '.[] \
		| {"ServiceName":.Config.Labels."com.docker.compose.service", "Status":.State.Health.Status}' \
		| tee /dev/tty | (! grep -q "unhealthy\|starting") \
		|| (echo "ProvisioingException: All the services in the cluster are still not healthy." && exit 1)

register-runners: status ## register all the runners in the cluster as shared runner to the master
	@echo "All services are healthy."
	@echo "Now attempting to register a new runner....."
	@HOST_GATEWAY_IP=$$(docker inspect `docker ps --format '{{.Names}}' \
		| grep -E 'gitlab-docker-sandbox.*master'` \
		| jq -r '.[].NetworkSettings.Networks | .[].Gateway'); \
		echo "HOST_GATEWAY_IP: $$HOST_GATEWAY_IP"; \
		docker-compose exec -T gitlab-runner-host \
			gitlab-runner register \
			--non-interactive \
			--registration-token "$(SHARED_RUNNER_REGISTRATION_TOKEN)" \
			--description alpine \
			--url "http://gitlab.example.com:8000" \
			--clone-url "http://$$HOST_GATEWAY_IP:8000" \
			--executor docker \
			--docker-image alpine:stable

create-sandbox-user: status ## create a non admin user for use with the sandbox
	@echo "All services are healthy."
	@echo "Creating admin api token....."
	@docker-compose exec -T gitlab-master \
		gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:api, :sudo], name: 'admin-token'); token.set_token('RandomAccessToken-$(RANDOM_ID)'); token.save!"; \
	USER_CREATION_STATUS=$$(curl -ks -o /dev/null -w "%{http_code}" -X POST \
		--header "PRIVATE-TOKEN: RandomAccessToken-$(RANDOM_ID)" \
		-d "email=$(SANDBOX_USERNAME)@example.com" \
		-d "password=$(SANDBOX_USER_PASSWORD)" \
		-d "username=$(SANDBOX_USERNAME)" \
		-d "name=$(SANDBOX_USERNAME)" \
		-d "skip_confirmation=true" \
		"https://gitlab.example.com/api/v4/users"); \
	if [ $$USER_CREATION_STATUS -eq 409 ]; then echo "AdminException: User already exists"; else echo "User Created!"; fi

get-concurrency: status ## get global job concurrency limit
	@echo "All services are healthy."
	@echo "Now checking current global job concurrency limit....."
	@CONCURRENCY_LIMIT=$$(docker-compose exec -T gitlab-runner-host \
		sed -n 's/^concurrent = //p' /etc/gitlab-runner/config.toml); echo "Global Job Concurrency : $$CONCURRENCY_LIMIT"

set-concurrency: status ## set global job concurrency limit
	@echo "All services are healthy."
	@echo "Now attempting to set the global job concurrency limit....."
ifdef concurrency
	@docker-compose exec -T gitlab-runner-host \
		sed -i '/^concurrent /s/=.*$/= $(concurrency)/' /etc/gitlab-runner/config.toml
	@echo "New Global Job Concurrency : $(concurrency)
else
	@echo 'RunnerException: You need to pass concurrency variable for using this make target'
endif

clean-runners: ## Unregister all runners from gitlab-master
	@docker-compose exec -T gitlab-runner-host \
		gitlab-runner unregister \
		--all-runners

down: gitlab-cleanup ## take down cluster and remove containers
	@echo "Removing service containers and volumes"
	@docker-compose down -v --remove-orphans

logs: ## cluster logs
	docker-compose logs -f