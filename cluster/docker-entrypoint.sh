#!/bin/bash
# docker-entrypoint.sh — unified startup for all Slurm services.
# CMD selects the service: slurmctld | slurmd | slurmdbd
# Inspired by https://github.com/giovtorres/slurm-docker-cluster
set -e

# ── helpers ────────────────────────────────────────────────────────────────────
wait_for() {
    local host="$1" port="$2"
    echo "[entrypoint] Waiting for ${host}:${port} ..."
    until bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; do
        sleep 2
    done
    echo "[entrypoint] ${host}:${port} is ready."
}

# ── munge (required by every service) ─────────────────────────────────────────
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
gosu munge munged --foreground &
sleep 2

# ── service dispatch ───────────────────────────────────────────────────────────
case "$1" in

    slurmdbd)
        # Fix slurmdbd.conf permissions (must be 600, owned by slurm)
        chown slurm:slurm /etc/slurm/slurmdbd.conf
        chmod 600 /etc/slurm/slurmdbd.conf

        wait_for postgres 5432
        echo "[entrypoint] Starting slurmdbd..."
        exec gosu slurm slurmdbd -D
        ;;

    slurmctld)
        wait_for slurmdbd 6819
        echo "[entrypoint] Starting slurmctld..."
        exec gosu slurm slurmctld -D
        ;;

    slurmd)
        wait_for slurmctld 6817
        echo "[entrypoint] Starting slurmd on $(hostname)..."
        # -N flag uses the container hostname as the node name, matching slurm.conf
        exec gosu slurm slurmd -D -N "$(hostname)"
        ;;

    *)
        exec "$@"
        ;;
esac
