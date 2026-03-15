# apptainer_poc

A local multi-node HPC cluster simulation for studying **Apptainer**, **Slurm**, and **Python Dask**.

Follows the [UPPMAX Singularity/Apptainer workshop](https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/) pattern for running Slurm-aware containers.

---

## Architecture

```
Host machine (Pop!_OS)
│
├── Podman (rootless)
│   ├── postgres         ← PostgreSQL 18 — job accounting database
│   ├── slurmdbd         ← Slurm database daemon
│   ├── slurmctld        ← Head / login node  (submit jobs from here)
│   ├── dask-scheduler   ← Slurm node: partition=dask-scheduler
│   ├── c1               ← Slurm node: partition=dask-workers + compute
│   └── c2               ← Slurm node: partition=dask-workers + compute
│
└── shared/         ← Cluster shared filesystem (/scratch equivalent)
    ├── images/     ← Apptainer .sif images
    ├── scripts/    ← Python/shell scripts run inside jobs
    ├── jobs/       ← Slurm batch scripts
    └── output/     ← Job stdout/stderr logs
```

**Slurm partitions:**

| Partition | Nodes | Purpose |
|-----------|-------|---------|
| `compute` | c1, c2 | General-purpose jobs (default) |
| `dask-scheduler` | dask-scheduler | Dedicated Dask scheduler node |
| `dask-workers` | c1, c2 | Dask worker jobs |

**Key design points:**
- Apptainer is installed **inside** each node image (not bind-mounted from host)
- The [UPPMAX bind-mount pattern](https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/) is demonstrated: Slurm commands work from **within** an Apptainer container by bind-mounting the node's Slurm binaries + munge socket
- `slurmdbd` + PostgreSQL 18 provide full job accounting (`sacct`)
- All Slurm nodes share a single image (`localhost/cluster_slurm`) built from `cluster/Containerfile`

---

## Prerequisites

| Tool | Install |
|------|---------|
| Podman 4.0+ | `sudo apt install podman podman-compose` |

Apptainer is **not required on the host** — it is installed inside the cluster image. It is only needed if you want to build `.sif` images on the host.

---

## Quick Start

### 1. One-time setup

```bash
make setup
# or: ./setup.sh
```

This will:
1. Generate the munge authentication key
2. Configure `~/.config/containers/registries.conf` for local image resolution
3. Build the cluster image (`localhost/cluster_slurm`) and tag it for all services
4. Sync scripts/jobs to `/shared`
5. Start all containers with `podman-compose up -d`

### 2. Shell into the head node

```bash
make shell
# or: podman exec -it slurmctld bash
```

### 3. Explore the cluster

```bash
sinfo          # node and partition status
squeue         # running/pending jobs
sacct          # completed job accounting
```

### 4. Submit jobs

```bash
# Hello world — runs on both compute nodes via Apptainer
sbatch /shared/jobs/hello.sh

# Dask distributed — scheduler + workers as Slurm jobs
sbatch /shared/jobs/dask_scheduler.sh   # runs on dask-scheduler node (partition=dask-scheduler)
sbatch /shared/jobs/dask_workers.sh     # runs on c1 + c2 (partition=dask-workers)
python3 /shared/scripts/dask_hello.py   # connect client and run tasks

# UPPMAX demo — calls sinfo/squeue from WITHIN an Apptainer container
sbatch /shared/jobs/uppmax_demo.sh

# Monitor
squeue
cat /shared/output/<job_name>_<jobid>.out
```

---

## The UPPMAX Bind-Mount Pattern

On real HPC clusters (e.g. UPPMAX Rackham), Slurm is on the bare-metal host. When a workflow runs inside an Apptainer container and needs to submit sub-jobs, you bind-mount the host's Slurm components into the container:

```bash
apptainer exec \
  -B /usr/bin/sbatch,/usr/lib64/slurm,/etc/slurm,/run/munge,/usr/lib64/libmunge.so.2 \
  container.sif workflow_script.sh
```

Inside the script, patch the slurm user identity:

```bash
export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
echo "slurm:x:990:990:Slurm:/:/sbin/nologin" >> /etc/passwd
echo "slurm:x:990:" >> /etc/group
sbatch next_step.sh   # works inside the container
```

`jobs/uppmax_demo.sh` and `scripts/uppmax_demo.sh` demonstrate this on the local simulation cluster.

---

## Project Structure

```
apptainer_poc/
├── Makefile                       # make setup / build / up / down / shell / status
├── setup.sh                       # one-time setup script
├── cluster/
│   ├── Containerfile              # Ubuntu 24.04 LTS + Slurm + Munge + Apptainer 1.4.5
│   ├── docker-entrypoint.sh       # unified startup: slurmctld | slurmd | slurmdbd
│   ├── podman-compose.yml         # postgres + slurmdbd + slurmctld + dask-scheduler + c1 + c2
│   └── conf/
│       ├── slurm.conf             # Slurm cluster configuration (nodes + partitions)
│       └── slurmdbd.conf          # Slurm accounting daemon → PostgreSQL
├── containers/
│   └── python.def                 # Apptainer: Python 3.11 + NumPy + SciPy
├── jobs/
│   ├── hello.sh                   # multi-node hello world (Apptainer + Slurm)
│   ├── dask_scheduler.sh          # sbatch: starts dask-scheduler on dask-scheduler node
│   ├── dask_workers.sh            # sbatch: starts dask-worker on c1 + c2 via srun
│   └── uppmax_demo.sh             # sbatch: UPPMAX bind-mount pattern demo
├── scripts/
│   ├── hello.py                   # runs inside python.sif
│   ├── dask_hello.py              # Dask client: connects to scheduler, maps hello() across workers
│   └── uppmax_demo.sh             # runs inside Apptainer, calls sinfo/squeue
└── shared/                        # cluster shared filesystem (bind-mounted into all nodes)
    ├── images/                    # built .sif files (gitignored)
    ├── scripts/                   # synced from scripts/ by setup.sh
    ├── jobs/                      # synced from jobs/ by setup.sh
    └── output/                    # job stdout/stderr logs (gitignored)
```

---

## Cluster Management

```bash
make build       # build cluster image + tag for all services
make up          # build + start cluster
make down        # stop cluster
make shell       # shell into head node (slurmctld)
make status      # sinfo
make queue       # squeue
make logs        # tail slurmctld logs
make clean       # stop + remove all volumes (full reset)
make rebuild     # rebuild image from scratch (no cache) + restart
```

## Notes

### podman-compose image naming
podman-compose 1.0.6 always derives image names as `<project>_<service>` regardless of the `image:` field. The build step tags `localhost/cluster_slurm` with all expected names (`localhost/cluster_c1`, `localhost/cluster_slurmctld`, etc.) and `~/.config/containers/registries.conf` is configured to search `localhost` for unqualified names.

### Apptainer on host
Not required for running the cluster. Only needed to build `.sif` images locally:
```bash
apptainer build shared/images/python.sif containers/python.def
```
Alternatively, build from inside slurmctld:
```bash
podman exec -it slurmctld apptainer build /shared/images/python.sif /shared/containers/python.def
```
