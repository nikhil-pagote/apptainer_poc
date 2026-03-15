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
# Copy the read-only bind-mounted key to /tmp so we can chown it without
# touching the host file, then start munged with the socket dir owned by munge.
cp /etc/munge/munge.key /tmp/munge.key
chown munge:munge /tmp/munge.key
chmod 400 /tmp/munge.key
mkdir -p /run/munge
chown munge:munge /run/munge
gosu munge munged --key-file /tmp/munge.key --foreground &
sleep 2

# ── service dispatch ───────────────────────────────────────────────────────────
case "$1" in

    slurmdbd)
        # slurmdbd requires slurmdbd.conf to be owned by SlurmUser and mode 600.
        # The bind-mounted template is root-owned (rootless Podman maps host user → root).
        # Copy the template to /etc/slurm/slurmdbd.conf, chown to slurm, then start.
        cp /etc/slurm/slurmdbd.conf.template /etc/slurm/slurmdbd.conf
        chown slurm:slurm /etc/slurm/slurmdbd.conf
        chmod 600 /etc/slurm/slurmdbd.conf
        wait_for mariadb 3306
        echo "[entrypoint] Starting slurmdbd..."
        exec slurmdbd -D
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
