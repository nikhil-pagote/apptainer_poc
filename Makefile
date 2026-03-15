.PHONY: setup build up down shell status logs clean rebuild

COMPOSE = podman-compose -f podman-compose.yml

# One-time setup: munge key + Apptainer images + start cluster
setup:
	./setup.sh

# Build container images only
build:
	cd cluster && podman build -t localhost/cluster_slurm -f Containerfile . \
		&& for svc in slurmdbd slurmctld dask-scheduler c1 c2; do podman tag localhost/cluster_slurm "localhost/cluster_$${svc}"; done

# Start the cluster (build first if needed)
up:
	cd cluster && podman build -t localhost/cluster_slurm -f Containerfile . \
		&& for svc in slurmdbd slurmctld dask-scheduler c1 c2; do podman tag localhost/cluster_slurm "localhost/cluster_$${svc}"; done \
		&& $(COMPOSE) up -d

# Stop the cluster
down:
	cd cluster && $(COMPOSE) down

# Open an interactive shell on the head node (submit jobs from here)
shell:
	podman exec -it slurmctld bash

# Show cluster node and partition status
status:
	podman exec slurmctld sinfo

# Show the job queue
queue:
	podman exec slurmctld squeue

# Tail logs from the head node
logs:
	podman logs -f slurmctld

# Stop cluster and remove all volumes (full reset)
clean:
	cd cluster && $(COMPOSE) down -v

# Rebuild images from scratch (no cache) and restart
rebuild:
	cd cluster && podman build --no-cache -t localhost/cluster_slurm -f Containerfile . \
		&& for svc in slurmdbd slurmctld dask-scheduler c1 c2; do podman tag localhost/cluster_slurm "localhost/cluster_$${svc}"; done \
		&& $(COMPOSE) up -d
