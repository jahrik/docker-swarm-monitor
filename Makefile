DATA_DIR?=./data
VERSION = "0.1.0"

all: dir config update deploy

config: ## Copy prometheus.yml to config dir
	@cp prometheus.yml $(DATA_DIR)/etc/prometheus.yml

dir: ## Create directories
	@mkdir -p \
		$(DATA_DIR)/etc \
		$(DATA_DIR)/grafana \
		$(DATA_DIR)/prometheus \
		|| echo "TRY SUDO"
	@chmod 777 $(DATA_DIR)/prometheus
	@chown -R nobody:nobody $(DATA_DIR)/prometheus

update: ## Pull latest docker images
	@docker pull grafana/grafana
	@docker pull prom/prometheus:latest
	@docker pull prom/node-exporter:latest

deploy: ## Deploy to docker swarm
	@docker stack deploy -c docker-stack.yml monitor

destroy: ## Docker stack rm && rm -rf data
	@docker stack rm monitor
	@rm -rf $(DATA_DIR)

help: ## This help dialog
	@IFS=$$'\n' ; \
		help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \
		for help_line in $${help_lines[@]}; do \
			IFS=$$'#' ; \
			help_split=($$help_line) ; \
			help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
			help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
			printf "%-10s %s\n" $$help_command $$help_info ; \
		done

.PHONY: all config destroy deploy dir docker help test update
