.PHONY: setup build up down shell status logs clean rebuild

# One-time setup: munge key + Apptainer images + start cluster
setup:
	./setup.sh

# Build container images only
build:
	cd cluster && podman-compose build

# Start the cluster (build first if needed)
up:
	cd cluster && podman-compose up -d

# Stop the cluster
down:
	cd cluster && podman-compose down

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
	cd cluster && podman-compose down -v

# Rebuild images from scratch (no cache) and restart
rebuild:
	cd cluster && podman-compose build --no-cache && podman-compose up -d
