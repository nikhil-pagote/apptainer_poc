# apptainer_poc

Apptainer-based HPC simulation featuring:

* **Slurm Workload Manager** – multi-node job scheduling
* **Python Dask Distributed** – distributed task execution across compute nodes
* **Docker Compose** – simulates a three-node HPC cluster on a single laptop/workstation
* **Apptainer definition file** – ready to build a portable `.sif` container for a real HPC cluster

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Docker network: hpc-net                                        │
│                                                                  │
│  ┌──────────────────┐     ┌────────────┐   ┌────────────┐      │
│  │  slurmctld       │     │  worker1   │   │  worker2   │      │
│  │  (head / login   │     │  (compute  │   │  (compute  │      │
│  │   node)          │     │   node)    │   │   node)    │      │
│  │                  │     │            │   │            │      │
│  │  slurmctld       │◄───►│  slurmd    │   │  slurmd    │      │
│  │  (port 6817)     │     │            │   │            │      │
│  └──────────────────┘     └────────────┘   └────────────┘      │
│           │                      │                │             │
│           └──────────────────────┴────────────────┘            │
│                         shared_data volume (/shared)            │
└────────────────────────────────────────────────────────────────┘
```

### Dask job flow

```
slurmctld (login node)
  │
  └─ sbatch submit_dask_job.sh     ← submit a 2-node job
          │
          ├── worker1  →  dask-scheduler  +  dask-client
          │                  │  (scheduler and client share the same node)
          │                  │
          └── worker2  →  dask-worker ──────────────────►  scheduler
                                 reports completed tasks
```

All 20 demo tasks are distributed across the worker nodes. Each result
contains the hostname and Dask worker ID to prove which node executed it.

---

## Repository layout

```
apptainer_poc/
├── apptainer/
│   └── python_dask.def        # Apptainer container definition (Python + Dask)
├── docker/
│   ├── Dockerfile             # Docker image: Ubuntu 22.04 + Slurm + Python/Dask
│   ├── docker-compose.yml     # Three-node cluster topology
│   └── entrypoint.sh          # Node initialisation (munge + Slurm daemons)
├── slurm/
│   ├── slurm.conf             # Slurm cluster configuration
│   └── cgroup.conf            # Minimal cgroup configuration
├── dask/
│   ├── dask_demo.py           # Dask distributed computing demo application
│   └── submit_dask_job.sh     # Slurm batch script (scheduler + workers + client)
└── scripts/
    ├── setup.sh               # Build Docker image (run once)
    ├── run_demo.sh            # Start cluster → submit job → print results
    └── reset.sh               # Stop cluster and remove volumes
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Docker Engine or Docker Desktop | ≥ 20.10 |
| Docker Compose plugin (`docker compose`) | ≥ 2.0 |
| (optional) Apptainer | ≥ 1.0 for building the `.sif` |

---

## Quick start

```bash
# 1. Build the Docker image (once)
bash scripts/setup.sh

# 2. Start the cluster, submit the Dask job, and print results
bash scripts/run_demo.sh

# 3. Clean up when done
bash scripts/reset.sh
```

---

## Step-by-step walkthrough

### 1 – Build the image

```bash
bash scripts/setup.sh
```

Builds `hpc-sim:latest` – an Ubuntu 22.04 image with Slurm, MUNGE, Python 3,
and `dask[distributed]`.

### 2 – Start the cluster

```bash
docker compose -f docker/docker-compose.yml up -d
```

Three containers start:

| Container | Hostname | Role |
|-----------|----------|------|
| `slurmctld` | `slurmctld` | Slurm controller + login node |
| `worker1` | `worker1` | Compute node (slurmd) |
| `worker2` | `worker2` | Compute node (slurmd) |

The controller generates a MUNGE authentication key and shares it through the
`shared_data` Docker volume.  Worker nodes wait for the key before starting
`slurmd`.

### 3 – Verify the cluster

```bash
docker exec slurmctld sinfo
```

Expected output (nodes transition from `unk` to `idle` in ~30 s):

```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      2   idle worker[1-2]
```

### 4 – Submit the Dask job

```bash
docker exec slurmctld sbatch /shared/submit_dask_job.sh
```

Slurm allocates `worker1` and `worker2`.  Inside the job:

1. **Dask scheduler** starts on `worker1`.
2. **Dask worker** starts on `worker2` via `srun`.
3. **Dask client** (also on `worker1`) submits 20 tasks and collects results.

### 5 – Watch results

```bash
# The job ID is printed by sbatch (e.g. 1)
docker exec slurmctld cat /shared/output/dask_demo_1.out
```

Sample output:

```
=====================================================================
  Dask Distributed Computing Demo
=====================================================================
  Client hostname  : worker1
  Scheduler address: worker1:8786
  (client and scheduler share the same node)

  Dashboard        : http://worker1:8787/status

  Waiting for workers to connect …

  Connected workers (1):
    • worker-worker2                   host=worker2

─────────────────────────────────────────────────────────────────────
  Submitting 20 tasks to the cluster …
─────────────────────────────────────────────────────────────────────

  Results grouped by compute node:

  ┌─ Node: worker2  (20 tasks) ──────────────────────
  │  task= 1  result=      0.0000  time=    2.4 ms  worker=worker-worker2
  │  task= 2  result=   1415.9265  time=    2.1 ms  worker=worker-worker2
  ...
  └─────────────────────────────────────────────────

=====================================================================
  ✓ All 20 tasks completed successfully!
  ✓ Tasks distributed across 1 node(s): worker2
=====================================================================
```

---

## Building the Apptainer SIF (real HPC)

On a system with Apptainer installed:

```bash
# Build the container image
apptainer build apptainer/python_dask.sif apptainer/python_dask.def

# Copy to the shared filesystem
cp apptainer/python_dask.sif /shared/

# The submit_dask_job.sh will automatically detect and use the SIF:
#   apptainer exec /shared/python_dask.sif dask-scheduler …
#   apptainer exec /shared/python_dask.sif dask-worker …
#   apptainer exec /shared/python_dask.sif python3 dask_demo.py …
```

The batch script (`dask/submit_dask_job.sh`) auto-detects whether Apptainer and
the SIF are available and switches between native Python and containerised
execution transparently.

---

## Customisation

| What to change | Where |
|----------------|-------|
| Number of compute nodes | `slurm/slurm.conf` (`NodeName` lines) + `docker/docker-compose.yml` (add `worker3` service) |
| CPUs / memory per node | `slurm/slurm.conf` (`CPUs=` / `RealMemory=`) |
| Number of Dask tasks | `dask/dask_demo.py` (`num_tasks = 20`) |
| Python packages in SIF | `apptainer/python_dask.def` (`%post` section) |
| Slurm job resources | `#SBATCH` directives in `dask/submit_dask_job.sh` |

---

## Troubleshooting

**`sinfo` shows nodes in `down` state**

```bash
# Check slurmd logs on a worker
docker logs worker1
# Resume the node from the controller
docker exec slurmctld scontrol update NodeName=worker1 State=RESUME
```

**Job stays in `PD` (pending) state**

The nodes may still be initialising.  Wait 30–60 s and run `sinfo` again.

**`munged` authentication errors**

The munge key is generated once by the controller and stored in the shared
volume.  If the volume was recreated without restarting all containers:

```bash
bash scripts/reset.sh
bash scripts/run_demo.sh
```

---

## References

* [Apptainer documentation](https://apptainer.org/docs/)
* [Slurm Workload Manager](https://slurm.schedmd.com/)
* [Dask Distributed](https://distributed.dask.org/)
