# Docker Swarm monitoring - part 02 (Cadvisor, Pihole, and dashboards galore)

In [part 01](https://homelab.business/docker-swarm-monitoring-part-01/), I deployed [node exporter](https://github.com/prometheus/node_exporter), [Prometheus](https://github.com/prometheus/prometheus), and [Grafana](https://grafana.com/).  This time around, I will mention some of the problems I've run into since then and tack on another monitoring tool to the stack, [Cadvisor](https://github.com/google/cadvisor).  While I'm at it, I'll also forward [Pi-Hole](https://pi-hole.net/) metrics to a custom dashboard and put together an example Prometheus client with Python to monitor the temperature of my server with [lm_sensors](https://wiki.archlinux.org/index.php/lm_sensors) or [PySensors](https://pypi.org/project/PySensors/#description) and output that to a gauge in Grafana.

Since part 01, I have added enough to [deploy this to Docker Swarm](https://github.com/jahrik/docker-swarm-monitor/blob/master/monitor/templates/monitor-stack.yml.j2) using a [Jenkins pipeline](https://github.com/jahrik/docker-swarm-monitor/blob/master/Jenkinsfile) and [Ansible playbook](https://github.com/jahrik/docker-swarm-monitor/blob/master/playbook.yml).  This workflow lets me push my changes to github, have Jenkins handle building and testing, then push to production with Ansible AWX.  There is a [write-up on doing the same thing with an Ark server](https://homelab.business/ark-jenkins-ansible-swarm/), if you need more information on how all those pieces fit together.

## Fix
I changed the permission to the Grafana SQLite.db file and it was still able to read data, but I wasn't able to save anything.  Somewhere along the line I ended up running `chown 1000:1000 /data/grafana/grafana.db`, Grafana did not like that.

![grafana_save_dashboard_error.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/grafana_save_dashboard_error.png?raw=true)

The following was observed in `docker service logs -f monitor_grafana`

    monitor_grafana.1.tyxisxhoxri4@<redacted_docker_host>    | t=2018-05-18T05:54:07+0000 lvl=eror msg="Failed to save dashboard" logger=context userId=1 orgId=1 uname=admin error="attempt to write a readonly database"

Plus a repeating stream of the following error, over and over.

    monitor_grafana.1.tyxisxhoxri4@<redacted_docker_host>    | t=2018-05-18T05:57:59+0000 lvl=eror msg="Failed to update last_seen_at" logger=context userId=1 orgId=1 uname=admin error="attempt to write a readonly database"
    monitor_grafana.1.tyxisxhoxri4@<redacted_docker_host>    | t=2018-05-18T05:57:59+0000 lvl=eror msg="Failed to update last_seen_at" logger=context userId=1 orgId=1 uname=admin error="attempt to write a readonly database"
    monitor_grafana.1.tyxisxhoxri4@<redacted_docker_host>    | t=2018-05-18T05:57:59+0000 lvl=eror msg="Failed to update last_seen_at" logger=context userId=1 orgId=1 uname=admin error="attempt to write a readonly database"
    monitor_grafana.1.tyxisxhoxri4@<redacted_docker_host>    | t=2018-05-18T05:57:59+0000 lvl=eror msg="Failed to update last_seen_at" logger=context userId=1 orgId=1 uname=admin error="attempt to write a readonly database"

Which makes it pretty obvious what's going on:
* msg="Failed to save dashboard"
* msg="Failed to update last_seen_at"
* error="attempt to write a readonly database"

This was an easy fix.

Find the grafana container and note the container id.

    docker ps

    CONTAINER ID        IMAGE                           COMMAND                  CREATED             STATUS                  PORTS                                                                            NAMES
    5dbad5cc02a1        grafana/grafana:latest          "/run.sh"                21 minutes ago      Up 21 minutes           3000/tcp                                                                         monitor_grafana.1.tyxisxhoxri40hfv56ecgr46i

Execute a shell on the docker container.

    docker exec -it 5dbad5cc02a1 bash

Get grafana user id info

    grafana@5dbad5cc02a1:/$ id
    uid=472(grafana) gid=472(grafana) groups=472(grafana)

On the docker host, set the file permission to of the volume.

    sudo chown 472:427 grafana/grafana.db

Kill and restart the grafana service

    docker service rm monitor_grafana 

    docker stack deploy -c monitor-stack.yml monitor
    Creating service monitor_grafana
    Updating service monitor_prometheus
    Updating service monitor_exporter
    Updating service monitor_pihole-exporter

Write access is restored.

![grafana_save_dashboard.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/grafana_save_dashboard.png?raw=true)

## Prometheus
Kill prometheus if the config file has changed.

    - name: Generate config files
      become: true
      template:
        src: prometheus.yml.j2
        dest: "{{ monitor_dir }}/etc/prometheus/prometheus.yml"
        mode: 0644
      register: prom_conf

    - name: Check if prometheus is running
      ignore_errors: true
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:9090/graph"
        status_code: 200
      register: result

    - name: kill prometheus service if conf file changes
      become: true
      command: docker service rm monitor_prometheus
      when:
        - result.status == 200
        - prom_conf.changed

## Cadvisor
## Pihole
## Pihole exporter
## Node exporter
