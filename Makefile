DATA_DIR?=./data
VERSION = "0.1.0"

all: dir config update deploy

config:
	@cp prometheus.yml $(DATA_DIR)/etc/prometheus.yml

dir:
	@mkdir -p \
		$(DATA_DIR)/etc \
		$(DATA_DIR)/grafana \
		$(DATA_DIR)/prometheus \
		|| echo "### TRY SUDO ###"
	@chmod 777 $(DATA_DIR)/prometheus
	@chown -R nobody:nobody $(DATA_DIR)/prometheus

update:
	@docker pull grafana/grafana
	@docker pull prom/prometheus:latest
	@docker pull prom/node-exporter:latest

deploy:
	@docker stack deploy -c docker-stack.yml monitor

destroy:
	@docker stack rm monitor
	@rm -rf $(DATA_DIR)

.PHONY: all config dir docker test update deploy destroy
