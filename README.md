# Docker Swarm Monitoring - Part 01 (Prometheus, Node-exporter, and Grafana)

Monitoring can be configured across a Docker Swarm cluster using services managed by swarm itself. Start with the prometheus node-exporter to gather system info from the hardware machine, Docker is running on.  You'll have to mount the system's directories as docker volumes to accomplish this.  This will gather system info and export it to a website that Prometheus server can then scrape every 15 seconds or so.  With those 2 services in place, Grafana can then be pointed at the Prometheus server to build beautiful graphs and charts about system usage.

Docker Swarm uses [Compose v3](https://docs.docker.com/compose/compose-file/) and uses a `docker-stack.yml` file, much like the `docker-compose.yml` files designed to be used with the `docker-compose` tool, which use Compose v2.  One of the biggest differences you'll run into when starting services with `docker stack deploy` over `docker-compose up/down` is that docker swarm creates a [Routing Mesh](https://docs.docker.com/engine/swarm/ingress/) for you, where as with `docker-compose` networks and containers have to be explicitly created and linked.  In swarm mode, the `link: ` is no longer needed.  Services can be included in the same stack file and by default be generated in the same network stack at deploy time, allowing docker containers to call each other by service name.  This network can then be used by other stacks and future services by calling it in the stack file and assigning a service to it.  This makes it easy to keep containers on their own isolated containers or to cluster certain services like metrics and logging tools together on the same private network.

Here is a Compose v3 docker-stack.yml file for this project that will start three services: Grafana, Prometheus server, and Prometheus node-exporter.  Directory creation needs to be done before deploying this stack.  A Makefile has been included to handle config, build, deploy, destroy operations and should be used as a reference for the commands that will build this thing.

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

Check the service

    docker service ps monitor_exporter

    ID                  NAME                                         IMAGE                       NODE                DESIRED STATE       CURRENT STATE                ERROR               PORTS
    cp7o7s9t33s6        monitor_exporter.76g7crzb0hk6jp9zysvegmupy   prom/node-exporter:latest   localhost           Running             Running about a minute ago

Check the logs

    docker service logs monitor_exporter
    ...
    ...
    monitor_exporter.0.cp7o7s9t33s6@localhost    | time="2018-03-28T08:14:47Z" level=info msg="Listening on :9100" source="node_exporter.go:76"

Browse to [localhost:9100/](http://localhost:9100/) and check it out.

#### IMAGE ####

### Server

* [Prometheus Server](https://github.com/prometheus/prometheus)
  * Docker mounted volumes for persistent data
    * ./data/prometheus:/prometheus:rw
    * Without this, all data is lost with a container restart
    * nobody:nobody is default prometheus user in the docker container
  * Docker mounted volumes for configuration
    * ./data/etc/prometheus.yml:/etc/prometheus/prometheus.yml:ro

Prepare directories for mounting docker volumes.  These will need read/write permissions for the default prometheus container user, which is nobody:nobody.

    DATA_DIR="./data"

    mkdir -p \
      "$DATA_DIR/etc" \
      "$DATA_DIR/grafana" \
      "$DATA_DIR/prometheus"

    chmod 777 "$DATA_DIR/prometheus"
    chown -R nobody:nobody "$DATA_DIR/prometheus"

## Grafana

## Cadvisor

## Elasticsearch
## Logstash
## Logspout
## Kibana
