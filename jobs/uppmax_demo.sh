#!/bin/bash
# uppmax_demo.sh — Demonstrates the UPPMAX bind-mount pattern:
#   Running an Apptainer container that can also call Slurm commands.
#
# Reference: https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/
#
# On real HPC clusters (e.g. UPPMAX/Rackham), Slurm is on the host and you
# bind-mount its binaries + munge socket into the container so that workflow
# scripts running inside Apptainer can submit sub-jobs via sbatch.
#
# In this simulation the "host" is the compute node container (c1 or c2),
# which has Slurm installed at /usr/bin and the munge socket at /run/munge.

#SBATCH --job-name=uppmax_demo
#SBATCH --output=/shared/output/uppmax_demo_%j.out
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --time=00:05:00

echo "=== UPPMAX Bind-Mount Demo ==="
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo ""

# ── UPPMAX pattern: bind Slurm components into the Apptainer container ────────
# These paths are from the compute node (the "host" for the Apptainer container):
#   /usr/bin/sbatch,squeue,scancel  — Slurm client binaries
#   /usr/lib/x86_64-linux-gnu/slurm-wlm — Slurm plugin libraries
#   /usr/lib/x86_64-linux-gnu/libmunge.so.2 — Munge shared library
#   /etc/slurm — Slurm configuration (slurm.conf)
#   /run/munge — Munge socket (live auth daemon)
#
# The script inside the container patches /etc/passwd and /etc/group to add
# the slurm user/group (matching UID/GID 990 set in our Containerfile).

SLURM_BINDS="\
/usr/bin/sbatch,\
/usr/bin/squeue,\
/usr/bin/scancel,\
/usr/bin/sinfo,\
/usr/lib/x86_64-linux-gnu/slurm-wlm,\
/usr/lib/x86_64-linux-gnu/libmunge.so.2,\
/etc/slurm,\
/run/munge"

apptainer exec -B "${SLURM_BINDS}" \
    /shared/images/python.sif \
    /shared/scripts/uppmax_demo.sh

echo ""
echo "=== Demo complete ==="
