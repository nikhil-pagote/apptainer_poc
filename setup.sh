#!/bin/bash
# setup.sh — One-time cluster setup:
#   1. Generate munge authentication key
#   2. Build Apptainer .sif images
#   3. Copy scripts/jobs to shared filesystem
#   4. Build and start the Podman cluster
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
MUNGE_KEY="$REPO_ROOT/cluster/conf/munge.key"
SHARED="$REPO_ROOT/shared"

echo "==> Generating munge key..."
if [ ! -f "$MUNGE_KEY" ]; then
    dd if=/dev/urandom bs=1 count=1024 > "$MUNGE_KEY" 2>/dev/null
    chmod 400 "$MUNGE_KEY"
    echo "    Created: $MUNGE_KEY"
else
    echo "    Already exists, skipping."
fi

echo "==> Building Apptainer .sif images (may take a few minutes)..."
cd "$REPO_ROOT"

if [ ! -f "$SHARED/images/python.sif" ]; then
    apptainer build "$SHARED/images/python.sif" containers/python.def
    echo "    Built: python.sif"
else
    echo "    python.sif already exists, skipping."
fi

if [ ! -f "$SHARED/images/dask.sif" ]; then
    apptainer build "$SHARED/images/dask.sif" containers/dask.def
    echo "    Built: dask.sif"
else
    echo "    dask.sif already exists, skipping."
fi

echo "==> Syncing scripts and jobs to shared filesystem..."
cp -r "$REPO_ROOT/scripts/." "$SHARED/scripts/"
cp -r "$REPO_ROOT/jobs/."    "$SHARED/jobs/"
echo "    Done."

echo "==> Building and starting the Slurm cluster..."
cd "$REPO_ROOT/cluster"
podman-compose build
podman-compose up -d

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Cluster is up!                                              ║"
echo "║  Services: mysql  slurmdbd  slurmctld  c1  c2               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Shell into the head node:"
echo "    make shell"
echo "    # or: podman exec -it slurmctld bash"
echo ""
echo "  Inside the head node, submit jobs:"
echo "    sinfo                              # view nodes"
echo "    sbatch /shared/jobs/hello.sh       # multi-node hello"
echo "    sbatch /shared/jobs/dask_job.sh    # Dask workload"
echo "    sbatch /shared/jobs/uppmax_demo.sh # UPPMAX bind-mount pattern"
echo "    squeue                             # job queue"
echo "    cat /shared/output/<job>.out       # view output"
