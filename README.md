# Docker Swarm Monitoring - Part 01 (Node-exporter, Prometheus, and Grafana)

Monitoring can be configured across a Docker Swarm cluster using services managed by swarm itself. Start with the prometheus node-exporter to gather system info from the hardware machine Docker is running on.  You'll have to mount the system's directories as docker volumes to accomplish this.  This will gather system info and export it to a website that Prometheus server can then scrape every 15 seconds or so.  With those 2 services in place, Grafana can then be pointed at the Prometheus server to build beautiful graphs and charts about system usage.

![grafana_node_exporter](https://raw.githubusercontent.com/jahrik/docker-swarm-monitor/master/images/grafana_node_exporter.png)

Prerequisites: 
* [Docker Install Docs](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
* [Docker Swarm Docs](https://docs.docker.com/engine/reference/commandline/swarm_init/)
* [github.com/jahrik/docker-swarm-monitor](https://github.com/jahrik/docker-swarm-monitor)

Docker Swarm uses [Compose v3](https://docs.docker.com/compose/compose-file/) and uses a `docker-stack.yml` file, much like the `docker-compose.yml` files designed to be used with the `docker-compose` tool, which use Compose v2.  One of the biggest differences you'll run into when starting services with `docker stack deploy` over `docker-compose up/down` is that docker swarm creates a [Routing Mesh](https://docs.docker.com/engine/swarm/ingress/) for you, where as with `docker-compose` networks and containers have to be explicitly created and linked.  In swarm mode, the `link: ` is no longer needed.  Services can be included in the same stack file and by default be generated in the same network stack at deploy time, allowing docker containers to call each other by service name.  This network can then be used by other stacks and future services by calling it in the stack file and assigning a service to it.  This makes it easy to keep containers on their own isolated containers or to cluster certain services like metrics and logging tools together on the same private network.

Here is a Compose v3 docker-stack.yml file for this project that will start three services: Grafana, Prometheus server, and Prometheus node-exporter.

**docker-stack.yml**

    version: '3'

    services:

      exporter:
        image: prom/node-exporter:latest
        ports:
          - '9100:9100'
        volumes:
          - /sys:/host/sys:ro
          - /:/rootfs:ro
          - /proc:/host/proc:ro
        deploy:
          mode: global

      prometheus:
        image: prom/prometheus:latest
        ports:
          - '9090:9090'
        volumes:
          - ./data/etc/prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - ./data/prometheus:/prometheus:rw
        deploy:
          mode: replicated
          replicas: 1

      grafana:
        image: grafana/grafana
        ports:
          - "3000:3000"
        volumes:
          - ./data/grafana:/var/lib/grafana:rw
        deploy:
          mode: replicated
          replicas: 1

Directory creation needs to be done before deploying this stack.  A [Makefile](https://github.com/jahrik/docker-swarm-monitor/blob/master/Makefile) has been included to handle config, build, deploy, destroy operations and should be used as a reference for the commands that will build this thing.

    make help                                                                              

    config:    Copy prometheus.yml to config dir
    dir:       Create directories
    update:    Pull latest docker images
    deploy:    Deploy to docker swarm
    destroy:   Docker stack rm && rm -rf data
    help:      This help dialog

## Prometheus

### Exporter

Browse to the [Prometheus node-exporter](https://github.com/prometheus/node_exporter) docs up on github and you'll see a few lines at the bottom of the readme that say how to run this in docker that look like this.

    docker run -d \
      --net="host" \
      --pid="host" \
      quay.io/prometheus/node-exporter

Start by creating the stack file with just this entry.  Take the image name from the docs and add it the stack file.  The volumes in the stack file are mounted for prometheus to read.  `deploy: mode: global` is saying that this service will be started on every node in the swarm cluster.  Outputs to [localhost:9100/](http://localhost:9100/)

**docker-stack.yml**

    version: '3'

    services:

      exporter:
        image: prom/node-exporter:latest
        ports:
          - '9100:9100'
        volumes:
          - /sys:/host/sys:ro
          - /:/rootfs:ro
          - /proc:/host/proc:ro
        deploy:
          mode: global

Start this up with the `docker stack deploy` command

    docker stack deploy -c docker-stack.yml monitor

    Creating network monitor_default
    Creating service monitor_exporter

This can also be kicked off with the Makefile

    make deploy

    Updating service monitor_exporter (id: ivbddqpnjr7sdxre0gzopney9)

Check the service

    docker service ps monitor_exporter

    ID                  NAME                                         IMAGE                       NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
    cp7o7s9t33s6        monitor_exporter.76g7crzb0hk6jp9zysvegmupy   prom/node-exporter:latest   localhost           Running             Running about a minute ago

Check the logs

    docker service logs monitor_exporter
    ...
    ...
    monitor_exporter.0.cp7o7s9t33s6@localhost    | time="2018-03-28T08:14:47Z" level=info msg="Listening on :9100" source="node_exporter.go:76"

Browse [localhost:9100/](http://localhost:9100/) and check it out.

![node_exporter](https://raw.githubusercontent.com/jahrik/docker-swarm-monitor/master/images/node_exporter.png)

### Server

Next, start up the [Prometheus Server](https://github.com/prometheus/prometheus).  This will scrape the exporter at a (10 second interval) set in the prometheus.yml configuration file.  This file will be configured locally and copied to the image as a volume at run time.  Volumes will also be used for persistent tsdb data in case of a container restart or failure.

**docker-stack.yml**

    prometheus:
      image: prom/prometheus:latest
      ports:
        - '9090:9090'
      volumes:
        - ./data/etc/prometheus.yml:/etc/prometheus/prometheus.yml:ro
        - ./data/prometheus:/prometheus:rw
      deploy:
        mode: replicated
        replicas: 1

Prepare directories for mounting docker volumes.  These will need read/write permissions for the default prometheus container user, which is nobody:nobody.

    DATA_DIR="./data"

    mkdir -p \
      "$DATA_DIR/etc" \
      "$DATA_DIR/grafana" \
      "$DATA_DIR/prometheus"

    chmod 777 "$DATA_DIR/prometheus"
    chown -R nobody:nobody "$DATA_DIR/prometheus"

Volumes are configured in the docker-stack.yml file. The first one is where prometheus will write it's database to.  Secondly, prometheus mounts the prometheus.yml file which will come in handy later, when I start deploying this with jenkins later, because it let's me edit this file and reconfigure prometheus at deploy time.
* ./data/prometheus:/prometheus:rw
* ./data/etc/prometheus.yml:/etc/prometheus/prometheus.yml:ro

Check out your prometheus.yml file and make sure the exporter is added as a scrape target.  This is how targets will be added in the future.  Like Cadvisor and mysql-exporter.

**prometheus.yml**

    scrape_configs:

      # http://exporter:9100/metrics
      - job_name: exporter
        scrape_interval: 10s
        metrics_path: "/metrics"
        static_configs:
        - targets:
           - exporter:9100

Use make to deploy and it will copy this config file to where it needs to go.

    make config

**Makefile**

    config:
	    @cp prometheus.yml $(DATA_DIR)/etc/prometheus.yml

With the prometheus server service added to the docker-stack.yml file and everything configured, redeploy the stack to add the new service.

    docker stack deploy -c docker-stack.yml monitor

    Creating service monitor_prometheus
    Updating service monitor_exporter (id: ivbddqpnjr7sdxre0gzopney9)

Browse to [localhost:9090/targets](http://127.0.0.1:9090/targets) to verify connectivity.

![prometheus_targets](https://raw.githubusercontent.com/jahrik/docker-swarm-monitor/master/images/prometheus_targets.png)


## Grafana

## Cadvisor

## Elasticsearch
## Logstash
## Logspout
## Kibana
