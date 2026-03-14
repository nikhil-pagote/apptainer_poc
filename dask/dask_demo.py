#!/usr/bin/env python3
"""
Dask Distributed Computing Demo
================================
Demonstrates:
  * Multiple Dask workers (each on its own HPC compute node) processing tasks
    in parallel.
  * Every task reports the hostname and Dask worker ID it ran on.
  * The Dask client and scheduler both reside on the scheduler / head node.

Usage:
    python3 dask_demo.py [SCHEDULER_ADDRESS]

    SCHEDULER_ADDRESS defaults to "localhost:8786" for standalone testing.
"""

import math
import os
import socket
import sys
import time

from dask.distributed import Client, LocalCluster, get_worker


# ── Per-task helper ──────────────────────────────────────────────────────────

def _worker_info() -> dict:
    """Return identifying information about the running Dask worker."""
    try:
        w = get_worker()
        return {"worker_name": w.name, "worker_addr": str(w.address)}
    except Exception:
        return {"worker_name": "unknown", "worker_addr": "unknown"}


def compute_task(x: int) -> dict:
    """
    A sample CPU-bound task.

    Performs a moderately expensive computation so the work is visible in
    timing, then returns the result together with provenance information
    (which node / worker executed it).
    """
    info = _worker_info()
    hostname = socket.gethostname()
    t0 = time.time()

    # Simulate work: sum of square-roots
    result = sum(math.sqrt(i) for i in range(x * 1000))

    elapsed_ms = (time.time() - t0) * 1000.0
    return {
        "input":      x,
        "result":     round(result, 4),
        "elapsed_ms": round(elapsed_ms, 2),
        "worker":     info["worker_name"],
        "hostname":   hostname,
    }


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> None:
    scheduler_address = sys.argv[1] if len(sys.argv) > 1 else None

    print("=" * 65)
    print("  Dask Distributed Computing Demo")
    print("=" * 65)
    print(f"  Client hostname  : {socket.gethostname()}")

    if scheduler_address:
        print(f"  Scheduler address: {scheduler_address}")
        print(f"  (client and scheduler share the same node)")
        print()
        client = Client(scheduler_address, timeout=30)
    else:
        print("  No scheduler address supplied – starting a local cluster.")
        print()
        cluster = LocalCluster(n_workers=2, threads_per_worker=1)
        client = Client(cluster)
        scheduler_address = client.scheduler.address

    print(f"  Dashboard        : {client.dashboard_link}")

    # Give workers time to register
    print("\n  Waiting for workers to connect …")
    client.wait_for_workers(1, timeout=30)
    time.sleep(2)

    # List connected workers
    workers = client.scheduler_info().get("workers", {})
    print(f"\n  Connected workers ({len(workers)}):")
    for addr, info in workers.items():
        print(f"    • {info.get('name', addr):<30}  host={info.get('host', 'unknown')}")

    # ── Submit work ──────────────────────────────────────────────────────────
    num_tasks = 20
    print(f"\n{'─' * 65}")
    print(f"  Submitting {num_tasks} tasks to the cluster …")
    print(f"{'─' * 65}")

    futures = client.map(compute_task, range(1, num_tasks + 1))
    results = client.gather(futures)

    # ── Aggregate by node ────────────────────────────────────────────────────
    by_node: dict[str, list] = {}
    for r in results:
        by_node.setdefault(r["hostname"], []).append(r)

    print("\n  Results grouped by compute node:")
    for hostname in sorted(by_node):
        tasks = by_node[hostname]
        print(f"\n  ┌─ Node: {hostname}  ({len(tasks)} tasks) ──────────────────────")
        for t in tasks:
            print(
                f"  │  task={t['input']:>2}  "
                f"result={t['result']:>12.4f}  "
                f"time={t['elapsed_ms']:>7.1f} ms  "
                f"worker={t['worker']}"
            )
        print(f"  └{'─' * 57}")

    # ── Summary ──────────────────────────────────────────────────────────────
    print(f"\n{'=' * 65}")
    print(f"  ✓ All {len(results)} tasks completed successfully!")
    print(
        f"  ✓ Tasks distributed across {len(by_node)} node(s): "
        + ", ".join(sorted(by_node))
    )
    print(f"{'=' * 65}\n")

    client.close()


if __name__ == "__main__":
    main()
