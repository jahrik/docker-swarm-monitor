# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Purpose

A Docker Compose monitoring stack — Prometheus, Grafana, node-exporter, cAdvisor — usable as-is with plain compose or adapted for Docker Swarm.

There is no Docker image built here; the stack runs upstream images only.

## Layout

- `docker-compose.yml` — the full stack definition with named volumes for persistence
- `prometheus.yml` — Prometheus scrape config; bind-mounted into the container at runtime
- `README.md` — quickstart and dashboard import instructions

## Common operations

```bash
docker compose up -d          # start the stack
docker compose logs -f        # follow logs
docker compose restart prometheus   # reload after editing prometheus.yml
docker compose down           # stop (volumes preserved)
docker compose down -v        # stop and delete all data
```

For local Swarm testing with dswarm (dind under Podman):

```bash
podman start dind
dswarm stack deploy --resolve-image never -c docker-compose.yml monitor
dswarm service ls
```

## Adding scrape targets

Edit `prometheus.yml` and add a job under `scrape_configs`, then `docker compose restart prometheus`. Service names in the compose file resolve as DNS hostnames within the stack network.
