FROM ubuntu:22.04

LABEL maintainer="HPC-Sim-POC"
LABEL description="HPC simulation node with Slurm and Python/Dask"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Authentication daemon used by Slurm
    munge \
    # Slurm workload manager (controller + worker in one package)
    slurm-wlm \
    # Python runtime
    python3 \
    python3-pip \
    # Run processes as a specific user without sudo
    gosu \
    # Utilities
    curl \
    vim \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# ── Python packages ──────────────────────────────────────────────────────────
RUN pip3 install --no-cache-dir \
    "dask[distributed]>=2023.1.0" \
    "numpy>=1.24.0" \
    "pandas>=2.0.0"

# ── Slurm directory layout ───────────────────────────────────────────────────
RUN mkdir -p \
        /var/spool/slurmctld \
        /var/spool/slurmd \
        /var/log/slurm \
        /etc/slurm \
    && chown slurm:slurm \
        /var/spool/slurmctld \
        /var/spool/slurmd \
        /var/log/slurm

# ── Container entry point ────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 6817 6818 8786 8787

ENTRYPOINT ["/entrypoint.sh"]
