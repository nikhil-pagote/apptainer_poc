# apptainer_poc

A local multi-node HPC cluster simulation for studying **Apptainer**, **Slurm**, and **Python Dask**.

Follows the [UPPMAX Singularity/Apptainer workshop](https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/) pattern for running Slurm-aware containers.

---

## Architecture

```
Host machine (Pop!_OS)
│
├── Podman (rootless)
│   ├── postgres    ← PostgreSQL 18 — job accounting database
│   ├── slurmdbd    ← Slurm database daemon
│   ├── slurmctld   ← Head / login node  (submit jobs here)
│   ├── c1          ← Compute node 1  (slurmd + Apptainer)
│   └── c2          ← Compute node 2  (slurmd + Apptainer)
│
└── shared/         ← Cluster shared filesystem (/scratch equivalent)
    ├── images/     ← Apptainer .sif images
    ├── scripts/    ← Python/shell scripts run inside jobs
    ├── jobs/       ← Slurm batch scripts
    └── output/     ← Job stdout/stderr logs
```

**Key design points:**
- Apptainer is installed **inside** each compute node image — no bind-mounting from host
- The [UPPMAX bind-mount pattern](https://pmitev.github.io/UPPMAX-Singularity-workshop/CaseStudies/SLURM_in_container/) is demonstrated: Slurm commands (`sbatch`, `squeue`) work from **within** an Apptainer container by bind-mounting the node's Slurm binaries + munge socket
- `slurmdbd` + PostgreSQL 18 provide full job accounting (`sacct`)

---

## Prerequisites

| Tool | Install |
|------|---------|
| Apptainer 1.4+ | `sudo apt install ./apptainer_1.4.5_amd64.deb` |
| Podman 4.0+ | `sudo apt install podman podman-compose` |

---

## Quick Start

### 1. One-time setup

```bash
make setup
# or: ./setup.sh
```

This generates the munge key, builds Apptainer `.sif` images, and starts the cluster.

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
# Hello world — runs on both compute nodes
sbatch /shared/jobs/hello.sh

# Dask parallel computation
sbatch /shared/jobs/dask_job.sh

# UPPMAX demo — calls sbatch/sinfo from WITHIN an Apptainer container
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

The `jobs/uppmax_demo.sh` and `scripts/uppmax_demo.sh` demonstrate this pattern on the local simulation cluster.

---

## Project Structure

```
apptainer_poc/
├── Makefile                       # make setup / up / down / shell / status
├── setup.sh                       # one-time setup script
├── cluster/
│   ├── Containerfile              # Ubuntu 24.04 LTS + Slurm + Munge + Apptainer
│   ├── docker-entrypoint.sh       # unified startup: slurmctld | slurmd | slurmdbd
│   ├── podman-compose.yml         # postgres + slurmdbd + slurmctld + c1 + c2
│   └── conf/
│       ├── slurm.conf             # Slurm cluster configuration
│       └── slurmdbd.conf          # Slurm accounting daemon configuration
├── containers/
│   ├── python.def                 # Apptainer: Python 3.11 + NumPy + SciPy
│   └── dask.def                   # Apptainer: Python 3.11 + Dask
├── jobs/
│   ├── hello.sh                   # multi-node hello world
│   ├── dask_job.sh                # Dask parallel computation
│   └── uppmax_demo.sh             # UPPMAX bind-mount pattern demo
├── scripts/
│   ├── hello.py                   # runs inside python.sif
│   ├── dask_example.py            # runs inside dask.sif
│   └── uppmax_demo.sh             # runs inside Apptainer, calls sinfo/squeue
└── shared/                        # cluster shared filesystem
    ├── images/                    # built .sif files (gitignored)
    ├── scripts/                   # synced from scripts/ by setup.sh
    ├── jobs/                      # synced from jobs/ by setup.sh
    └── output/                    # job logs (gitignored)
```

---

## Cluster Management

```bash
make up          # start cluster
make down        # stop cluster
make shell       # shell into head node
make status      # sinfo
make queue       # squeue
make logs        # tail slurmctld logs
make clean       # stop + remove all volumes (full reset)
make rebuild     # rebuild images from scratch
```

## Rebuilding Apptainer Images

```bash
apptainer build shared/images/python.sif containers/python.def
apptainer build shared/images/dask.sif   containers/dask.def
```
