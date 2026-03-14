# apptainer_poc

A local multi-node HPC cluster simulation for studying Apptainer, Slurm, and Python Dask.

## Architecture

```
Host machine (Pop!_OS)
│
├── Podman (rootless)
│   ├── slurmctld  ← head/login node  (submit jobs here)
│   ├── node1      ← compute node 1   (runs slurmd)
│   └── node2      ← compute node 2   (runs slurmd)
│
├── shared/              ← shared filesystem (bind-mounted into all nodes)
│   ├── images/          ← Apptainer .sif images
│   ├── scripts/         ← Python scripts run inside jobs
│   ├── jobs/            ← Slurm batch scripts
│   └── output/          ← Job stdout/stderr logs
│
└── /usr/bin/apptainer   ← bind-mounted into compute nodes
```

Slurm runs across the Podman containers. When a job runs on a compute node,
it calls `apptainer exec` to run the workload inside an Apptainer container —
exactly how real HPC clusters work.

## Prerequisites

- [Apptainer](https://apptainer.org/) 1.4+
- [Podman](https://podman.io/) 4.0+ with `podman-compose`

### Install Apptainer on Ubuntu / Pop!_OS

```bash
curl -LO https://github.com/apptainer/apptainer/releases/download/v1.4.5/apptainer_1.4.5_amd64.deb
sudo apt install -y ./apptainer_1.4.5_amd64.deb
apptainer --version
```

### Install Podman

```bash
sudo apt install -y podman podman-compose
```

## Quick Start

### 1. One-time setup

```bash
./setup.sh
```

This will:
- Generate a Munge authentication key
- Build Apptainer `.sif` images from `containers/*.def`
- Build and start the 3-node Podman cluster

### 2. Log into the head node

```bash
podman exec -it slurmctld bash
```

### 3. Check the cluster

```bash
sinfo          # view nodes and partitions
squeue         # view running jobs
```

### 4. Submit jobs

```bash
# Run hello.py on both compute nodes simultaneously
sbatch /shared/jobs/hello.sh

# Run a Dask parallel computation
sbatch /shared/jobs/dask_job.sh

# Monitor jobs
squeue

# View output
cat /shared/output/hello_<jobid>.out
```

## Project Structure

```
apptainer_poc/
├── cluster/
│   ├── Containerfile          # Ubuntu + Slurm + Munge base image
│   ├── podman-compose.yml     # 3-node cluster definition
│   ├── conf/
│   │   └── slurm.conf         # Slurm configuration
│   └── entrypoint/
│       ├── slurmctld.sh       # Head node startup
│       └── slurmd.sh          # Compute node startup
├── containers/
│   ├── python.def             # Apptainer: Python + NumPy + SciPy
│   └── dask.def               # Apptainer: Python + Dask
├── jobs/
│   ├── hello.sh               # Multi-node hello world job
│   └── dask_job.sh            # Dask parallel computation job
├── scripts/
│   ├── hello.py               # Runs inside python.sif
│   └── dask_example.py        # Runs inside dask.sif
├── shared/                    # Cluster shared filesystem
│   ├── images/                # Built .sif files (gitignored)
│   ├── scripts/               # Copied from scripts/ by setup.sh
│   ├── jobs/                  # Copied from jobs/ by setup.sh
│   └── output/                # Job logs (gitignored)
└── setup.sh                   # One-time setup script
```

## Cluster Management

```bash
# Start the cluster
cd cluster && podman-compose up -d

# Stop the cluster
cd cluster && podman-compose down

# View logs
podman logs slurmctld
podman logs node1

# Rebuild after changes to Containerfile
cd cluster && podman-compose build && podman-compose up -d
```

## Rebuilding Apptainer Images

```bash
# Rebuild after editing a .def file
apptainer build shared/images/python.sif containers/python.def
apptainer build shared/images/dask.sif   containers/dask.def
```
