#!/bin/bash
#SBATCH --job-name=dask-scheduler
#SBATCH --output=/shared/output/dask_scheduler_%j.out
#SBATCH --partition=dask-scheduler
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --time=00:30:00

echo "Starting Dask scheduler on $(hostname) at $(date)"

# Write scheduler address to shared filesystem so workers and client can find it
dask scheduler --scheduler-file /shared/dask-scheduler.json
