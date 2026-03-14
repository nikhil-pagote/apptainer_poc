"""
dask_hello.py — Dask client that connects to a running dask-scheduler
and submits simple tasks that print the worker's hostname.

Workflow (run from slurmctld head node):
    sbatch /shared/jobs/dask_scheduler.sh
    sbatch /shared/jobs/dask_workers.sh
    python3 /shared/scripts/dask_hello.py
"""

import socket
from dask.distributed import Client

SCHEDULER_FILE = "/shared/dask-scheduler.json"

print(f"Connecting to Dask scheduler via {SCHEDULER_FILE} ...")
client = Client(scheduler_file=SCHEDULER_FILE)
print(client)

def hello(task_id):
    return f"Hello from {socket.gethostname()} (task {task_id})"

futures = client.map(hello, range(4))
results = client.gather(futures)

print("\n--- Results ---")
for r in results:
    print(r)

client.close()
