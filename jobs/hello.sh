#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --output=/shared/output/hello_%j.out
#SBATCH --ntasks=2
#SBATCH --nodes=2
#SBATCH --time=00:05:00

echo "Job started: $(date)"
echo "Running on nodes: $SLURM_NODELIST"

# Run one task per node using the python.sif Apptainer container
srun apptainer exec /shared/images/python.sif python3 /shared/scripts/hello.py

echo "Job finished: $(date)"
