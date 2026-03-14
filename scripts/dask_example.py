import socket
import os
import dask
import dask.array as da

node = socket.gethostname()
job_id = os.environ.get("SLURM_JOB_ID", "N/A")

print(f"Dask job on node={node}, job={job_id}")
print(f"Dask version: {dask.__version__}")

# Create a large random array in chunks and compute its mean
x = da.random.random((10_000, 10_000), chunks=(1_000, 1_000))
result = x.mean().compute()
print(f"Mean of 10000x10000 random array: {result:.6f}")
