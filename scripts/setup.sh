#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# setup.sh – Build the Docker image for the HPC simulation.
#
# Run this once before starting the cluster.
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

echo "============================================================"
echo " HPC Simulation – Setup"
echo "============================================================"
echo ""

# ── Dependency check ──────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in docker; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    # Accept both the old 'docker-compose' binary and the newer 'docker compose' plugin
    if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
        missing+=("docker-compose (or docker compose plugin)")
    fi
    if [ "${#missing[@]}" -ne 0 ]; then
        echo "ERROR: Missing required tools: ${missing[*]}"
        echo "       Please install Docker Desktop or Docker Engine + Compose."
        exit 1
    fi
}

check_deps
echo "  ✓ Docker and Docker Compose are available"
echo ""

# ── Build image ───────────────────────────────────────────────────────────────
echo "  Building Docker image hpc-sim:latest …"
cd "${REPO_DIR}"
docker compose -f docker/docker-compose.yml build --no-cache

echo ""
echo "  ✓ Image built successfully."
echo ""
echo "  Next step:"
echo "      ./scripts/run_demo.sh"
echo ""
