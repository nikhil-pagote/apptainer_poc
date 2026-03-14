import socket
import os
import numpy as np

node = socket.gethostname()
job_id = os.environ.get("SLURM_JOB_ID", "N/A")
task_id = os.environ.get("SLURM_PROCID", "0")

print(f"Hello from node={node}, job={job_id}, task={task_id}")
print(f"NumPy version: {np.__version__}")
print(f"pi ≈ {np.pi:.6f}")
