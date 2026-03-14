#!/bin/bash
#SBATCH --job-name=dask-workers
#SBATCH --output=/shared/output/dask_workers_%j.out
#SBATCH --ntasks=2
#SBATCH --nodes=2
#SBATCH --time=00:30:00

echo "Starting Dask workers on nodes: $SLURM_NODELIST at $(date)"

# Wait for scheduler file to appear (written by dask_scheduler.sh job)
echo "Waiting for scheduler file..."
until [ -f /shared/dask-scheduler.json ]; do sleep 2; done
echo "Scheduler file found."

# srun starts one dask-worker per allocated task (one on c1, one on c2)
srun dask worker --scheduler-file /shared/dask-scheduler.json
