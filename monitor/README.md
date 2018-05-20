Docker Swarm Monitor
=========

Configure directory structure for docker swarm volume mounts.
Deploy Prometheus, Cadvisor, Grafana, and more to docker swarm.

Requirements
------------

Role Variables
--------------

monitor_dir: '/data'

Dependencies
------------

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: monitor, monitor_dir: '/not_data/' }

License
-------

GPLv2

Author Information
------------------

[homelab.business](https://homelab.business/docker-swarm-monitoring-part-02-fixes-cadvisor-pihole/)
