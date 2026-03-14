#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Slurm batch script – Dask distributed computing demo
#
# Allocation: 2 nodes (worker1 + worker2)
#   • worker1 (first allocated node):  Dask scheduler  +  Dask client
#   • worker2 (remaining node(s)):     Dask worker(s)
#
# To run on the real HPC cluster replace the bare `dask-*` / `python3` calls
# with `apptainer exec /shared/python_dask.sif dask-*` etc.
# ─────────────────────────────────────────────────────────────────────────────
#SBATCH --job-name=dask_demo
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --output=/shared/output/dask_demo_%j.out
#SBATCH --error=/shared/output/dask_demo_%j.err
#SBATCH --time=00:10:00
#SBATCH --partition=debug

echo "======================================================================"
echo " Dask Demo – Slurm Job"
echo " Job ID  : ${SLURM_JOB_ID}"
echo " Nodes   : ${SLURM_JOB_NODELIST}"
echo " Started : $(date)"
echo "======================================================================"

# ── Node discovery ────────────────────────────────────────────────────────────
readarray -t NODELIST < <(scontrol show hostnames "${SLURM_JOB_NODELIST}")

SCHEDULER_NODE="${NODELIST[0]}"
WORKER_NODES=("${NODELIST[@]:1}")

echo ""
echo "  Scheduler/Client node : ${SCHEDULER_NODE}"
echo "  Worker node(s)        : ${WORKER_NODES[*]}"
echo ""

# ── Detect whether Apptainer is available ────────────────────────────────────
SIF_PATH="/shared/python_dask.sif"
if command -v apptainer &>/dev/null && [ -f "${SIF_PATH}" ]; then
    PYTHON_CMD="apptainer exec ${SIF_PATH} python3"
    DASK_SCHEDULER_CMD="apptainer exec ${SIF_PATH} dask-scheduler"
    DASK_WORKER_CMD="apptainer exec ${SIF_PATH} dask-worker"
    echo "  Mode: Apptainer (SIF=${SIF_PATH})"
else
    PYTHON_CMD="python3"
    DASK_SCHEDULER_CMD="dask-scheduler"
    DASK_WORKER_CMD="dask-worker"
    echo "  Mode: native Python (Apptainer SIF not found – using host Python)"
fi

SCHEDULER_PORT=8786
SCHEDULER_ADDR="${SCHEDULER_NODE}:${SCHEDULER_PORT}"

# ── Start Dask scheduler on the first allocated node ─────────────────────────
# The Slurm batch step itself runs on the first node, so we can start the
# scheduler directly here without srun.
echo ""
echo "  [$(date '+%H:%M:%S')] Starting Dask scheduler on ${SCHEDULER_NODE} …"
${DASK_SCHEDULER_CMD} \
    --host "${SCHEDULER_NODE}" \
    --port "${SCHEDULER_PORT}" \
    --no-dashboard \
    &
SCHEDULER_PID=$!

echo "  [$(date '+%H:%M:%S')] Scheduler PID ${SCHEDULER_PID} – waiting 8 s …"
sleep 8

# ── Start Dask workers on remaining nodes via srun ────────────────────────────
for WNODE in "${WORKER_NODES[@]}"; do
    echo "  [$(date '+%H:%M:%S')] Starting Dask worker on ${WNODE} …"
    srun \
        --nodes=1 \
        --ntasks=1 \
        --nodelist="${WNODE}" \
        --exclusive \
        ${DASK_WORKER_CMD} \
            "${SCHEDULER_ADDR}" \
            --nthreads "${SLURM_CPUS_PER_TASK}" \
            --name "worker-${WNODE}" \
            --no-dashboard \
        &
done

echo "  [$(date '+%H:%M:%S')] Waiting 10 s for workers to connect …"
sleep 10

# ── Run the Dask client on the scheduler node ─────────────────────────────────
echo ""
echo "  [$(date '+%H:%M:%S')] Running Dask client on ${SCHEDULER_NODE} …"
echo ""
${PYTHON_CMD} /shared/dask_demo.py "${SCHEDULER_ADDR}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
echo ""
echo "  [$(date '+%H:%M:%S')] Shutting down Dask processes …"
kill "${SCHEDULER_PID}" 2>/dev/null || true
wait

echo ""
echo "======================================================================"
echo " Job finished : $(date)"
echo "======================================================================"
