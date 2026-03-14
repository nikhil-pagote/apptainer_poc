#!/bin/bash
#SBATCH --job-name=dask
#SBATCH --output=/shared/output/dask_%j.out
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:10:00

echo "Dask job started: $(date)"
echo "Running on: $SLURMD_NODENAME"

apptainer exec /shared/images/dask.sif python3 /shared/scripts/dask_example.py

echo "Dask job finished: $(date)"
