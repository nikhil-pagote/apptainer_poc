#!/bin/bash
# setup.sh — One-time cluster setup: generate munge key, copy shared scripts,
#             build container images, and start the cluster.
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

echo "==> Copying scripts to shared filesystem..."
cp -r "$REPO_ROOT/scripts/." "$SHARED/scripts/"
cp -r "$REPO_ROOT/jobs/."    "$SHARED/jobs/"
echo "    Done."

echo "==> Building Apptainer images (this may take a few minutes)..."
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

echo "==> Building and starting the Slurm cluster..."
cd "$REPO_ROOT/cluster"
podman-compose build
podman-compose up -d

echo ""
echo "Cluster is up! Nodes: slurmctld (head), node1, node2"
echo ""
echo "Next steps:"
echo "  # Open a shell on the head node to submit jobs:"
echo "  podman exec -it slurmctld bash"
echo ""
echo "  # Inside the head node:"
echo "  sbatch /shared/jobs/hello.sh"
echo "  sbatch /shared/jobs/dask_job.sh"
echo "  squeue"
echo "  cat /shared/output/hello_<jobid>.out"
