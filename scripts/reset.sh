#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# reset.sh – Stop and remove all containers and volumes for the HPC simulation.
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

echo "Stopping HPC simulation cluster …"
cd "${REPO_DIR}"
docker compose -f docker/docker-compose.yml down -v --remove-orphans

echo "Cluster stopped and volumes removed."
