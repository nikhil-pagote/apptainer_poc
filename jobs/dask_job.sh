#!/bin/bash
#SBATCH --job-name=dask
#SBATCH --output=/shared/output/dask_%j.out
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:10:00

echo "Dask job started: $(date)"
echo "Running on: $SLURMD_NODENAME"

# Bind Slurm components into the container (UPPMAX bind-mount pattern).
# Allows the containerized script to submit sub-jobs via sbatch if needed.
SLURM_BINDS="\
/usr/bin/sbatch,\
/usr/bin/squeue,\
/usr/bin/scancel,\
/usr/lib/x86_64-linux-gnu/slurm-wlm,\
/usr/lib/x86_64-linux-gnu/libmunge.so.2,\
/etc/slurm,\
/run/munge"

apptainer exec -B "${SLURM_BINDS}" \
    /shared/images/dask.sif \
    python3 /shared/scripts/dask_example.py

echo "Dask job finished: $(date)"
