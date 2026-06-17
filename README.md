# Docker Swarm Monitoring

A monitoring stack for Docker Swarm using Prometheus, Grafana, node-exporter, and cAdvisor. Dashboards and the Prometheus datasource are provisioned automatically on first start.

## Services

| Service | Port | Description |
|---|---|---|
| Grafana | 3000 | Dashboards and visualization |
| Prometheus | 9090 | Metrics storage and query UI |
| node-exporter | — | Host system metrics (CPU, memory, disk, network) |
| cAdvisor | — | Per-container metrics |

## Deploy

### Docker Compose

```bash
docker compose up -d
```

### Docker Swarm

```bash
docker stack deploy --resolve-image never -c docker-compose.yml monitor
```

For node-exporter, add `deploy: mode: global` so it runs on every node rather than a single replica:

```yaml
node-exporter:
  deploy:
    mode: global
```

## Grafana

Browse to http://localhost:3000 — default credentials are `admin` / `admin`.

Two dashboards are provisioned automatically:

- **Node Exporter Full** — host metrics (CPU, memory, filesystem, network)
- **Cadvisor exporter** — per-container CPU, memory, and network

## Configuration

### Adding scrape targets

Edit `prometheus.yml` and add a job under `scrape_configs`. In Swarm mode, use `tasks.<service>` to resolve actual task IPs rather than VIPs:

```yaml
- job_name: my-service
  dns_sd_configs:
    - names: [tasks.my-service]
      type: A
      port: 8080
```

Restart Prometheus to reload:

```bash
# Compose
docker compose restart prometheus

# Swarm
docker service update --force monitor_prometheus
```

### Persistent data

Prometheus metrics and Grafana state persist in named Docker volumes (`prometheus_data`, `grafana_data`). To reset:

```bash
docker compose down -v
```
