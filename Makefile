DOCKER_STACK_CONFIG := docker stack config
DOCKER_STACK_CONFIG_ARGS := --skip-interpolation

UNAME_S := $(shell uname -s)
# macos := false

# ifeq ($(UNAME_S),Darwin)
#   macos := true
# endif

# if darwin == true, then use the cadvisor_docker_stack_darwin.yml file
cadvisor_docker_stack_file := cadvisor/docker-stack.yml
ifeq ($(UNAME_S),Darwin)
	cadvisor_docker_stack_file := cadvisor/docker-stack-macos.yml
  # echo "*****************************************************************"
  # echo "Darwin/Mac detected using macos cadvisor docker stack file"
  # echo "*****************************************************************"
endif

make: create-manifest
	@echo "Usage: make [deploy|remove|clean]"
	@echo "  deploy: Deploy the stack"
	@echo "  remove: Remove the stack"
	@echo "  clean: Clean up temporary files"

create-manifest:
	@mkdir -p _tmp
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c labeling-agent/docker-stack.yml > _tmp/labeling-agent.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c blackbox-exporter/docker-stack.yml > _tmp/blackbox-exporter.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c $(cadvisor_docker_stack_file) > _tmp/cadvisor.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c grafana/docker-stack.yml > _tmp/grafana.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c node-exporter/docker-stack.yml > _tmp/node-exporter.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c prometheus/docker-stack.yml > _tmp/prometheus.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) -c pushgateway/docker-stack.yml > _tmp/pushgateway.manifest.yml
	$(DOCKER_STACK_CONFIG) $(DOCKER_STACK_CONFIG_ARGS) \
		-c _tmp/blackbox-exporter.manifest.yml \
		-c _tmp/cadvisor.manifest.yml \
		-c _tmp/grafana.manifest.yml \
		-c _tmp/node-exporter.manifest.yml \
		-c _tmp/prometheus.manifest.yml \
		-c _tmp/pushgateway.manifest.yml \
    -c _tmp/labeling-agent.manifest.yml \
	> deployment.stack.yml
	# @rm -rf _tmp
	@sed "s|$(PWD)/||g" deployment.stack.yml > deployment.stack.yml.tmp
	@rm deployment.stack.yml
	@mv deployment.stack.yml.tmp deployment.stack.yml

deploy: create-manifest stack-deploy
remove: stack-remove

clean: stack-remove config-prune volume-prune
	@rm -rf _tmp || true
	@rm -f deployment.stack.yml || true

stack-deploy:
	docker network create --scope=swarm --driver=overlay --attachable public || true
	docker network create --scope=swarm --driver=overlay --attachable prometheus || true
	docker network create --scope=swarm --driver=overlay --attachable prometheus_gwnetwork || true
	docker stack deploy --with-registry-auth -c deployment.stack.yml promstack

stack-remove:
	docker stack rm promstack
config-prune:
	docker config ls -q | xargs docker config rm
volume-prune:
	docker volume ls -q | xargs docker volume rm
