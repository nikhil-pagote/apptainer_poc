#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --output=/shared/output/hello_%j.out
#SBATCH --ntasks=2
#SBATCH --nodes=2
#SBATCH --time=00:05:00

echo "Job started: $(date)"
echo "Running on nodes: $SLURM_NODELIST"

# Bind the host's Slurm binaries, libraries, config, and munge socket into the
# Apptainer container so that containerized code can also call sbatch/squeue if needed.
# This follows the UPPMAX bind-mount pattern for Slurm-in-container:
#   https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/
SLURM_BINDS="\
/usr/bin/sbatch,\
/usr/bin/squeue,\
/usr/bin/scancel,\
/usr/lib/x86_64-linux-gnu/slurm-wlm,\
/usr/lib/x86_64-linux-gnu/libmunge.so.2,\
/etc/slurm,\
/run/munge"

# Run one task per node inside the python.sif Apptainer container
srun apptainer exec -B "${SLURM_BINDS}" \
    /shared/images/python.sif \
    python3 /shared/scripts/hello.py

echo "Job finished: $(date)"
