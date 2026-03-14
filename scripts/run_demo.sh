#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run_demo.sh – Start the HPC simulation cluster and run the Dask demo job.
#
# Steps performed:
#   1. Start slurmctld + worker1 + worker2 containers
#   2. Wait for Slurm to become healthy
#   3. Display cluster node status (sinfo)
#   4. Submit the Dask batch job via sbatch
#   5. Poll until the job finishes and print the output
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
COMPOSE_FILE="${REPO_DIR}/docker/docker-compose.yml"

echo "============================================================"
echo " HPC Simulation – Run Demo"
echo "============================================================"
echo ""

# ── 1. Start cluster ──────────────────────────────────────────────────────────
echo "  Starting cluster …"
cd "${REPO_DIR}"
docker compose -f "${COMPOSE_FILE}" up -d

# ── 2. Wait for Slurm to be healthy ──────────────────────────────────────────
echo ""
echo "  Waiting for Slurm cluster to initialise (40 s) …"
sleep 40

# ── 3. Show cluster status ────────────────────────────────────────────────────
echo ""
echo "  ── Slurm node status (sinfo) ──────────────────────────────"
docker exec slurmctld sinfo || true
echo "  ────────────────────────────────────────────────────────────"
echo ""

# ── 4. Submit the Dask job ────────────────────────────────────────────────────
echo "  Submitting Dask demo job …"
JOB_OUTPUT=$(docker exec slurmctld sbatch /shared/submit_dask_job.sh 2>&1)
echo "  ${JOB_OUTPUT}"

JOB_ID=$(echo "${JOB_OUTPUT}" | grep -oP '(?<=Submitted batch job )\d+')
if [ -z "${JOB_ID}" ]; then
    echo "ERROR: Could not determine job ID from sbatch output."
    exit 1
fi
echo "  Job ID: ${JOB_ID}"

OUTPUT_FILE="/shared/output/dask_demo_${JOB_ID}.out"

# ── 5. Poll until job completes ───────────────────────────────────────────────
echo ""
echo "  Waiting for job ${JOB_ID} to complete (up to 3 min) …"
TIMEOUT=180
ELAPSED=0
while [ "${ELAPSED}" -lt "${TIMEOUT}" ]; do
    JOB_STATE=$(docker exec slurmctld squeue -j "${JOB_ID}" -h -o "%T" 2>/dev/null || echo "DONE")
    if [ "${JOB_STATE}" = "DONE" ] || [ -z "${JOB_STATE}" ]; then
        break
    fi
    echo "  Job state: ${JOB_STATE} (${ELAPSED}s elapsed) …"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

# ── 6. Print job output ───────────────────────────────────────────────────────
echo ""
echo "  ── Job output ─────────────────────────────────────────────"
docker exec slurmctld cat "${OUTPUT_FILE}" 2>/dev/null \
    || echo "  (output file not yet available – check ${OUTPUT_FILE} inside the container)"
echo "  ────────────────────────────────────────────────────────────"
echo ""
echo "  Demo complete. Run './scripts/reset.sh' to stop the cluster."
echo ""
