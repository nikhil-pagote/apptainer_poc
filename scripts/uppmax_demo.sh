#!/bin/bash
# uppmax_demo.sh — runs INSIDE the Apptainer container.
# Demonstrates the UPPMAX pattern: calling Slurm commands from within a container.
#
# The Slurm binaries and munge socket are bind-mounted in from the compute node
# (the host), so sbatch/squeue/sinfo work even though they are not installed
# in the python.sif container image.

set -e

echo "--- Inside Apptainer container ---"
echo "Container OS: $(cat /etc/os-release | grep PRETTY_NAME)"
echo ""

# Patch /etc/passwd and /etc/group so Slurm's UID/GID (990) is recognised.
# This is the exact technique from the UPPMAX workshop reference.
if ! grep -q "^slurm:" /etc/passwd; then
    echo "slurm:x:990:990:Slurm Workload Manager:/:/sbin/nologin" >> /etc/passwd
fi
if ! grep -q "^slurm:" /etc/group; then
    echo "slurm:x:990:" >> /etc/group
fi

# Set library path so munge and Slurm libs are found
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}

echo "Calling sinfo (cluster topology) from within the container:"
sinfo
echo ""

echo "Calling squeue (job queue) from within the container:"
squeue
echo ""

echo "Verifying Python is from the container (not the host):"
python3 -c "import sys; print('Python:', sys.version)"
echo ""

echo "Slurm commands work inside Apptainer via bind-mounts."
echo "This is the UPPMAX pattern for workflow containers."
