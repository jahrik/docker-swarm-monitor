# Docker Swarm monitoring - part 02 (Fixes, Cadvisor, Pihole, and dashboards galore)

In [part 01](https://homelab.business/docker-swarm-monitoring-part-01/), I deployed [node exporter](https://github.com/prometheus/node_exporter), [Prometheus](https://github.com/prometheus/prometheus), and [Grafana](https://grafana.com/).  This time around, I will mention some of the problems I've run into since then and tack on another monitoring tool to the stack, [Cadvisor](https://github.com/google/cadvisor).  While I'm at it, I'll also forward [Pi-Hole](https://pi-hole.net/) metrics to a custom dashboard and put together an example Prometheus client with Python to monitor the temperature of my server with [lm_sensors](https://wiki.archlinux.org/index.php/lm_sensors) or [PySensors](https://pypi.org/project/PySensors/#description) and output that to a gauge in Grafana.

Since part 01, I have added enough to [deploy this to Docker Swarm](https://github.com/jahrik/docker-swarm-monitor/blob/master/monitor/templates/monitor-stack.yml.j2) using a [Jenkins pipeline](https://github.com/jahrik/docker-swarm-monitor/blob/master/Jenkinsfile) and [Ansible playbook](https://github.com/jahrik/docker-swarm-monitor/blob/master/playbook.yml).  This workflow lets me push my changes to github, have Jenkins handle building and testing, then push to production with Ansible AWX.  There is a [write-up on doing the same thing with an Ark server](https://homelab.business/ark-jenkins-ansible-swarm/), if you need more information on how all those pieces fit together.

## Fixes

A few things I've learned along the way since part 01.

### Grafana

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

On the docker host, set the file permission to all the files on the host end of the volume.
Where `/data/grafana` is the mounted volume containing `/data/grafana/grafana.db`

    sudo chown -R 472:472 /data/grafana

Kill and restart the grafana service

    docker service rm monitor_grafana 

    docker stack deploy -c monitor-stack.yml monitor

Write access is restored.

![grafana_save_dashboard.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/grafana_save_dashboard.png?raw=true)

Here's what the Ansible task handling this now, looks like.

    - name: Create directories for grafana
      become: true
      file:
        path: "{{ item }}"
        state: directory
        owner: 472
        group: 472
        mode: 0755
        recurse: yes
      with_items:
        - "{{ monitor_dir }}/grafana"

### Prometheus

When you make an update to the prometheus.yml file, the desired action is for the Prometheus server to be restarted.  Because I'm deploying this in an automated fashion, I need to handle the restarting of this service the same way and add in a couple of checks along the way.  [This Ansible playbook can be found here](https://github.com/jahrik/docker-swarm-monitor/blob/master/monitor/tasks/main.yml).

*It all goes like this:*

The config file is generated and registers a variable, `prom_conf` containing information about the file in question, `prometheus.yml`, including information on whether the file has been changed this run or not.

    - name: Generate config files
      become: true
      template:
        src: prometheus.yml.j2
        dest: "{{ monitor_dir }}/etc/prometheus/prometheus.yml"
        mode: 0644
      register: prom_conf

A check to see if Prometheus is running or not with the [uri module](http://docs.ansible.com/ansible/latest/modules/uri_module.html).  This also registers a variable, `result` containing a status code returned from whatever webserver it's pointed at.  In this case, I'm pulling the default IPv4 address from the host that ansible is currently running on and adding `:9090/graph` to the end of that, in hopes of reaching Prometheus.  Notice how this one also has `ignore_erros: true`.  The reason for this, is for the very first time this runs on docker or for times when Prometheus is not actually running.  Without that, you will get a status_code back that does not equal 200 and this task will fail.

    - name: Check if prometheus is running
      ignore_errors: true
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:9090/graph"
        status_code: 200
      register: result

With these two checks in place, there is enough information to determine if the prometheus server needs to be restarted or not.  With a when statement that contains more than one thing, `when: ['one_thing','two_thing']`, both values have to be true before this task is kicked off. If the variable `prom_conf` comes back with a `.changed` status of `true` this will be passed on as true.  Same goes for the `result.status`, if it == 200 it will return `true`.

    - name: kill prometheus service if conf file changes
      become: true
      command: docker service rm monitor_prometheus
      when:
        - result.status == 200
        - prom_conf.changed

With that, the stack is redeployed to swarm, restarting Prometheus.

    - name: deploy the monitor stack to docker swarm
      become: true
      command: docker stack deploy -c monitor-stack.yml monitor
      args:
        chdir: "{{ monitor_dir }}/stacks/"


I've also added a check at the end of the playbook to make sure Prometheus is running.

    - name: Wait for prometheus port to come up
      wait_for:
        host: "{{ ansible_default_ipv4.address }}"
        port: 9090
        timeout: 30

### Node Exporter

I'm seeing the following from `docker service logs -f monitor_exporter`.  I would like node exporter to ignore docker volume mounts.  Ignoring all of /var/lib/docker would be ok with me for now to clean up this error, but I haven't figured out where to configure that yet.  It's on the TODO list.

    time="2018-05-19T08:33:59Z" level=error msg="Error on statfs() system call for \"/rootfs/var/lib/docker/overlay2/f8da180fa939589132d04099a37c9f182bc0b38e84d0b84ee8958fe42aa5e18d/merged\": permission denied" source="filesystem_linux.go:57"
    time="2018-05-19T08:33:59Z" level=error msg="Error on statfs() system call for \"/rootfs/var/lib/docker/containers/01358918338b67982715107fe876b803abbcd0c57f4672c07de0025d1426f2af/mounts/shm\": permission denied" source="filesystem_linux.go:57"
    time="2018-05-19T08:33:59Z" level=error msg="Error on statfs() system call for \"/rootfs/run/docker/netns/a2d163e99d44\": permission denied" source="filesystem_linux.go:57"

## Cadvisor

[Cadvisor](https://github.com/google/cadvisor) will export metrics from the container service running.
> cAdvisor has native support for Docker containers and should support just about any other container type out of the box. 

While running node_exporter alone and not Cadvisor yet, the [Docker-swarm-monitor dashboard](https://grafana.com/dashboards/2603) will look a bit like this.
![grafana_docker_swarm_dashboard_before.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/grafana_docker_swarm_dashboard_before.png?raw=true)

Add Cadvisor to the [monitor-stack.yml](https://github.com/jahrik/docker-swarm-monitor/blob/master/monitor/templates/monitor-stack.yml.j2) file.

    cadvisor:
      image: google/cadvisor:latest
      ports:
        - '9105:8080'
      volumes:
        - /var/lib/docker/:/var/lib/docker
        - /dev/disk/:/dev/disk
        - /sys:/sys
        - /var/run:/var/run
        - /:/rootfs
        - /dev/zfs:/dev/zfs
      deploy:
        mode: global
        resources:
          limits:
            cpus: '0.50'
            memory: 1024M
          reservations:
            cpus: '0.25'
            memory: 512M
        update_config:
          parallelism: 3
          monitor: 2m
          max_failure_ratio: 0.3
          failure_action: rollback
          delay: 30s
        restart_policy:
          condition: on-failure
          delay: 5s
          max_attempts: 3

Because I'm deploying this with a [webhook to jenkins](https://homelab.business/ark-jenkins-ansible-swarm/#webhook), the [commit](https://github.com/jahrik/docker-swarm-monitor/commit/ccc13342b8c58a08ce8da8488f2b414cc296f2a7) that added this ^ to the stack file deployed Cadvisor to the Swarm, as I'm writing this.

Cadvisor is viewable at [docker_host:9102/containers](docker_host:9102/containers/)

![cadvisor_exporter.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/cadvisor_exporter.png?raw=true)

Create a job in the [prometheus.yml](https://github.com/jahrik/docker-swarm-monitor/blob/master/monitor/templates/prometheus.yml.j2) file to import data from Cadvisor.

    # http://shredder:9102/metrics/
    - job_name: 'cadvisor'
      scrape_interval: 30s
      metrics_path: '/metrics'
      static_configs:
      - targets:
        - docker_host:9102

With that deployed, a new target is added to `Prometheus > targets`, [docker_host:9090/targets](docker_host:9090/targets/)

![prometheus_targets.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/prometheus_targets.png?raw=true)

Refresh the docker swarm monitor dashboard and there should be a lot more info now!

![grafana_docker_swarm_dashboard_with_cadvisor.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/grafana_docker_swarm_dashboard_with_cadvisor.png?raw=true)

## Pihole

[Pi-Hole](https://github.com/pi-hole/pi-hole) is running on a raspberry pi. It acts as the DNS and DHCP server for the network, while caching DNS queries and providing "a [DNS sinkhole](https://en.wikipedia.org/wiki/DNS_sinkhole) that protects your devices from unwanted content, without installing any client-side software."  It blocks a surprising amount of ad content from things like Facebook, news sites, and blog posts, like this one, which uses Google Adsense. It worked well enough, in-fact, I had to add google analytics to the whitelist after setting this up to access the site and check metrics.

![pihole.png](https://github.com/jahrik/docker-swarm-monitor/blob/master/images/pihole.png?raw=true)

Seeing the results and experiencing an increase in query speeds, was worth the hour or so of fussing with pfsense. Finally, disabling DHCP and DNS forwarding altogether on the firewall and just letting Pi-Hole handle it worked.  The dashboard that comes with pihole is great and really all you need for this service, but it's also nice to have in a central location with other monitoring tools and graphs.  One way to accomplish this is with the [pihole_exporter](https://github.com/nlamirault/pihole_exporter) for prometheus.  I fought with this for a couple of hours before getting it to work.  Eventually building it from source with docker and pushing it up to docker hub to pull into swarm.

## Pihole exporter
## Node exporter
