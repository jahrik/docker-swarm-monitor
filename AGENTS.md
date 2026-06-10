# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Purpose

Tutorial repo behind the homelab.business "Docker Swarm monitoring" article series (part 01 in `README.md`, part 02 in `PART_02.md`). It documents and automates a Swarm monitoring stack — node-exporter, Prometheus, Grafana, cAdvisor, and a Pi-hole exporter — with screenshots in `images/`.

There is **no Docker image built here** — the stack runs upstream images (`prom/prometheus`, `grafana/grafana`, `prom/node-exporter`, etc.).

## Layout

- `README.md` / `PART_02.md` — the tutorial articles themselves; they link to files in this repo at specific paths, so be careful when renaming or deleting anything
- `monitor/` — Ansible role that creates the volume directory structure (with the uid/gid quirks Grafana 472 and Prometheus 65534 expect), templates `prometheus.yml` and `monitor-stack.yml`, and deploys the stack to Swarm
- `playbook.yml` — entry point applying the `monitor` role (`monitor_dir` is the ZFS pool path)
- `Makefile` — the manual pre-Ansible flow from part 01 (mkdir/chown, copy config, `docker stack deploy`)
- `Jenkinsfile` — Jenkins → Ansible Tower deployment pipeline; **referenced by PART_02.md as tutorial content, do not delete**

## Working on it

This is a docs/tutorial archive, not active infrastructure. Keep changes documentation-shaped; there is no CI and no release pipeline. If the Ansible role is ever modernized (FQCN modules, molecule), follow the patterns from the `ansible-*` role repos.
