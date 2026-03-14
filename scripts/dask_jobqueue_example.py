"""
dask_jobqueue_example.py — Dask + Slurm via dask-jobqueue.

SLURMCluster submits each Dask worker as an sbatch job to the Slurm cluster.
Workers run on compute nodes (c1, c2) and connect back to the Dask scheduler
running in the dask-client container. All containers share slurm-net so
hostname resolution works transparently.

Reference: https://jobqueue.dask.org/en/latest/generated/dask_jobqueue.SLURMCluster.html
"""

import time
import socket
from dask_jobqueue import SLURMCluster
from dask.distributed import Client

print(f"Dask client starting on host: {socket.gethostname()}")

# ── Create a SLURMCluster ─────────────────────────────────────────────────────
# Each scale() call submits one sbatch job that starts a Dask worker.
# Workers inherit the cluster's Python environment (installed in the image).
cluster = SLURMCluster(
    cores=1,
    memory="256MB",
    queue="compute",
    job_extra_directives=[
        "--output=/shared/output/dask_worker_%j.out",
    ],
    python="/usr/bin/python3",
    scheduler_options={"host": "dask-client"},   # workers resolve this via slurm-net
)

print(cluster.job_script())   # print the generated sbatch script for learning

# Submit 2 Slurm jobs, one per compute node
cluster.scale(2)
print("Submitted 2 Slurm jobs for Dask workers — waiting for them to connect...")

# ── Connect a Dask Client to the scheduler ────────────────────────────────────
client = Client(cluster)
client.wait_for_workers(n_workers=2, timeout=120)
print(f"Workers connected: {client.scheduler_info()['workers'].keys()}")

# ── Run a simple distributed computation ─────────────────────────────────────
import dask.array as da

x = da.random.random((5_000, 5_000), chunks=(1_000, 1_000))
mean = x.mean().compute()
print(f"Mean of 5000×5000 random array: {mean:.6f}")

# Show which nodes handled the work
def node_name():
    return socket.gethostname()

futures = client.map(node_name, range(8))
nodes = client.gather(futures)
print(f"Tasks ran on nodes: {set(nodes)}")

client.close()
cluster.close()
print("Done.")
