#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Container entry point – handles both the Slurm controller and compute nodes.
#
# Environment variables consumed:
#   NODE_TYPE   "controller" | "worker"  (default: worker)
#   SHARED_DIR  path to the shared volume (default: /shared)
# ─────────────────────────────────────────────────────────────────────────────
set -e

NODE_TYPE="${NODE_TYPE:-worker}"
SHARED_DIR="${SHARED_DIR:-/shared}"
MUNGE_KEY_PATH="${SHARED_DIR}/munge.key"

# ── Logging helper ────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%H:%M:%S')] [$(hostname)] [${NODE_TYPE}] $*"
}

# ── Ensure shared output directory exists ─────────────────────────────────────
mkdir -p "${SHARED_DIR}/output"

# ── Munge setup ───────────────────────────────────────────────────────────────
setup_munge() {
    if [ "${NODE_TYPE}" = "controller" ]; then
        log "Generating munge authentication key …"
        dd if=/dev/urandom bs=1 count=1024 > "${MUNGE_KEY_PATH}" 2>/dev/null
        chmod 400 "${MUNGE_KEY_PATH}"
        log "Munge key written to ${MUNGE_KEY_PATH}"
    else
        log "Waiting for munge key from controller …"
        local attempts=0
        while [ ! -f "${MUNGE_KEY_PATH}" ]; do
            sleep 1
            attempts=$((attempts + 1))
            if [ "${attempts}" -gt 60 ]; then
                log "ERROR: timed out waiting for munge key after 60 s"
                exit 1
            fi
        done
        log "Munge key found (waited ${attempts}s)"
    fi

    cp "${MUNGE_KEY_PATH}" /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key

    log "Starting munge daemon …"
    /usr/sbin/munged
    sleep 1
    log "Munge daemon running"
}

# ── Slurm controller ──────────────────────────────────────────────────────────
start_controller() {
    log "Setting up slurmctld (Slurm controller) …"

    mkdir -p /var/spool/slurmctld
    chown slurm:slurm /var/spool/slurmctld

    # Copy Dask helper scripts into the shared volume so every node can reach them
    if [ -d "/repo/dask" ]; then
        cp /repo/dask/dask_demo.py       "${SHARED_DIR}/dask_demo.py"
        cp /repo/dask/submit_dask_job.sh "${SHARED_DIR}/submit_dask_job.sh"
        chmod +x "${SHARED_DIR}/submit_dask_job.sh"
        log "Dask scripts copied to ${SHARED_DIR}"
    fi

    log "Starting slurmctld …"
    /usr/sbin/slurmctld -D &
    SLURMCTLD_PID=$!
    log "slurmctld started (PID ${SLURMCTLD_PID})"

    wait "${SLURMCTLD_PID}"
}

# ── Slurm compute node ────────────────────────────────────────────────────────
start_worker() {
    log "Setting up slurmd (Slurm compute node) …"

    # Give the controller a head-start so the node doesn't retry too many times
    log "Waiting for controller to become ready (8 s) …"
    sleep 8

    mkdir -p /var/spool/slurmd
    chown slurm:slurmd /var/spool/slurmd

    log "Starting slurmd …"
    /usr/sbin/slurmd -D &
    SLURMD_PID=$!
    log "slurmd started (PID ${SLURMD_PID})"

    wait "${SLURMD_PID}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
setup_munge

if [ "${NODE_TYPE}" = "controller" ]; then
    start_controller
else
    start_worker
fi
