#!/bin/bash
set -e

# Fix munge key permissions and start munge
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
gosu munge munged --foreground &

# Wait for munge to be ready
sleep 2

# Start slurmd in foreground
echo "Starting slurmd on $(hostname) (compute node)..."
exec gosu slurm slurmd -D -N "$(hostname)"
