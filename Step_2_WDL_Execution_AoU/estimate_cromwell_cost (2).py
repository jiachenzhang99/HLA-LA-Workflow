#!/usr/bin/env python3
"""
estimate_cromwell_cost
=======================

This module implements a simple cost‑estimation utility for workflows executed
with the Cromwell workflow engine on the All of Us Researcher Workbench. The
idea is to parse the JSON metadata produced by Cromwell (via
`cromshell‑alpha metadata <workflow_id> > metadata.json`) and tally up the
amount of compute and disk resources used by each task. Once resource usage
is known, the script multiplies it by configurable hourly rates to produce
an estimated cost.

The default pricing values used here are derived from examples in the All of
Us documentation and public Google Cloud pricing sources. These numbers
should be treated as rough approximations and may need to be adjusted for
your specific billing plan or region. To customize the rates, either edit
the constants defined below or pass new values on the command line.

Usage:

```
python estimate_cromwell_cost.py --metadata path/to/metadata.json \
    [--cpu-rate 0.0475] [--mem-rate 0.004] \
    [--cpu-rate-preempt 0.01] [--mem-rate-preempt 0.0008] \
    [--disk-rate 0.000055] [--ssd-rate 0.000233] [--local-ssd-rate 0.00011] \
    [--details]

# Alternatively, pipe the metadata through stdin:
cat metadata.json | python estimate_cromwell_cost.py
```

By default, the script prints a table summarizing each call along with its
runtime, CPU and memory allocation, disk usage and estimated cost. The final
line reports the total estimated cost for the workflow.

Limitations:
 - The script assumes that each call uses one disk as defined in
   `runtimeAttributes.disks` in the format "local-disk SIZE TYPE" where SIZE
   is specified in GB. If multiple disks are specified they will be summed.
 - Machine types are interpreted according to their name. Custom machines
   (e.g. `custom-4-16384`) are parsed directly. For standard machine
   families (e.g. `n1-standard-4`, `n1-highmem-8`) the script infers
   memory from the family name using typical per‑CPU memory ratios.
 - If the metadata does not include `end` timestamps, the current time is
   used to compute runtime, so cost estimates will reflect ongoing jobs.
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from math import ceil
from typing import Dict, Tuple, Any, List, Optional

try:
    from dateutil import parser as dtparser  # type: ignore
except ImportError:
    print(
        "This script requires python-dateutil. You can install it with:\n"
        "pip install python-dateutil",
        file=sys.stderr,
    )
    raise


# Default pricing constants (per hour). These values come from All of Us
# documentation and public GCP pricing examples【619589063615721†L112-L121】. Adjust
# them if your project uses different rates.
DEFAULT_CPU_RATE = 0.0475  # full price per vCPU per hour
DEFAULT_CPU_RATE_PREEMPT = 0.0100  # preemptible price per vCPU per hour
DEFAULT_MEM_RATE = 0.0040  # full price per GB RAM per hour
DEFAULT_MEM_RATE_PREEMPT = 0.0008  # preemptible price per GB RAM per hour
DEFAULT_DISK_RATE = 0.000055  # standard persistent disk per GB per hour
DEFAULT_SSD_RATE = 0.000233  # SSD persistent disk per GB per hour
DEFAULT_LOCAL_SSD_RATE = 0.000110  # local SSD per GB per hour


def parse_arguments() -> argparse.Namespace:
    """Parse command‑line arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Estimate the cost of a Cromwell workflow by analysing its metadata."
        )
    )
    parser.add_argument(
        "--metadata",
        "-m",
        type=str,
        help=(
            "Path to Cromwell metadata JSON. If omitted, metadata is read from stdin."
        ),
    )
    parser.add_argument(
        "--cpu-rate",
        type=float,
        default=DEFAULT_CPU_RATE,
        help="Cost per vCPU hour for non‑preemptible VMs (default: %(default)s)",
    )
    parser.add_argument(
        "--cpu-rate-preempt",
        type=float,
        default=DEFAULT_CPU_RATE_PREEMPT,
        help="Cost per vCPU hour for preemptible VMs (default: %(default)s)",
    )
    parser.add_argument(
        "--mem-rate",
        type=float,
        default=DEFAULT_MEM_RATE,
        help="Cost per GB RAM hour for non‑preemptible VMs (default: %(default)s)",
    )
    parser.add_argument(
        "--mem-rate-preempt",
        type=float,
        default=DEFAULT_MEM_RATE_PREEMPT,
        help="Cost per GB RAM hour for preemptible VMs (default: %(default)s)",
    )
    parser.add_argument(
        "--disk-rate",
        type=float,
        default=DEFAULT_DISK_RATE,
        help="Cost per GB hour for standard persistent disk (default: %(default)s)",
    )
    parser.add_argument(
        "--ssd-rate",
        type=float,
        default=DEFAULT_SSD_RATE,
        help="Cost per GB hour for SSD persistent disk (default: %(default)s)",
    )
    parser.add_argument(
        "--local-ssd-rate",
        type=float,
        default=DEFAULT_LOCAL_SSD_RATE,
        help="Cost per GB hour for local SSD (default: %(default)s)",
    )
    parser.add_argument(
        "--details",
        action="store_true",
        help="Print a detailed table of each call before the summary.",
    )
    return parser.parse_args()


def load_metadata(path: Optional[str]) -> Dict[str, Any]:
    """Load Cromwell metadata from the given file or stdin."""
    if path:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return json.load(sys.stdin)


def parse_iso8601(dt: str) -> datetime:
    """Convert an ISO 8601 timestamp into a timezone‑aware datetime object."""
    return dtparser.parse(dt)


def parse_size(size_str: str) -> float:
    """Parse a memory/disk size string into gigabytes.

    Supports strings such as '3.75 GB', '15GB', '16384 MB', '6000000000', '4G',
    or integer/float values in MB.
    """
    if isinstance(size_str, (int, float)):
        # Already a number, assume MB
        return float(size_str) / 1024
    s = size_str.strip().lower().replace("ib", "b")
    # Remove spaces between the number and units
    s = s.replace(" ", "")
    # Identify numeric component
    num = ""
    unit = ""
    for ch in s:
        if ch.isdigit() or ch == ".":
            num += ch
        else:
            unit += ch
    if not num:
        raise ValueError(f"Could not parse size string: {size_str}")
    value = float(num)
    if unit in ("g", "gb"):
        return value
    if unit in ("m", "mb"):
        return value / 1024
    if unit in ("k", "kb"):
        return value / (1024 * 1024)
    # If unit unknown, assume bytes
    if unit == "b" or unit == "":
        return value / (1024 * 1024 * 1024)
    raise ValueError(f"Unrecognized unit in size string: {size_str}")


def infer_machine_cpu_mem(machine_type: str) -> Tuple[int, float]:
    """Infer the number of vCPUs and memory (GB) for a given GCE machine type.

    This function supports custom machines (custom-N-M where M is MB),
    standard families (n1/e2 etc.), highmem and highcpu variants. For unknown
    families, it falls back to assuming 4 GB per CPU.
    """
    machine_type = machine_type.lower()
    # Custom: format custom-<cpus>-<memory_mb>
    if machine_type.startswith("custom-"):
        parts = machine_type.split("-")
        if len(parts) >= 3:
            cpu = int(parts[1])
            memory_mb = int(parts[2])
            memory_gb = memory_mb / 1024
            return cpu, memory_gb
    # Predefined types like n1-standard-4, n1-highmem-8, n1-highcpu-16
    family, _, cpu_str = machine_type.partition("-")
    # Remove optional 'n1-' prefix
    if '-' in family:
        base, family_variant = family.split('-', 1)
    else:
        base = family
        family_variant = ''
    try:
        cpus = int(cpu_str)
    except ValueError:
        # Fallback: unknown format
        return 1, 4.0
    # Determine memory ratio from variant
    if 'highmem' in machine_type:
        mem_per_cpu = 6.5
    elif 'highcpu' in machine_type:
        mem_per_cpu = 0.9  # approximate for highcpu
    else:
        # Standard machine families typically allocate ~3.75 GB per CPU
        mem_per_cpu = 3.75
    return cpus, cpus * mem_per_cpu


def extract_resources(call: Dict[str, Any]) -> Tuple[int, float, float, bool]:
    """Extract CPU count, memory (GB), total disk size (GB) and preemptible flag from a call."""
    attrs: Dict[str, Any] = call.get('runtimeAttributes', {})
    # CPU
    cpu = None
    if 'cpu' in attrs:
        try:
            cpu = int(attrs['cpu'])
        except Exception:
            pass
    # Memory
    memory_gb = None
    if 'memory' in attrs:
        try:
            memory_gb = parse_size(attrs['memory'])
        except Exception:
            pass
    # Disk sizes
    total_disk_gb = 0.0
    if 'disks' in attrs:
        # Cromwell concatenates multiple disk definitions separated by commas
        for disk_entry in attrs['disks'].split(','):
            parts = disk_entry.strip().split()
            if len(parts) >= 3:
                # Format: <name> <size> <type>
                size = parts[1]
                try:
                    total_disk_gb += parse_size(size + 'GB' if size.isdigit() else size)
                except Exception:
                    pass
    # Preemptible flag
    preemptible = bool(call.get('preemptible', False))
    # If CPU or memory not explicitly provided, fall back to machine type
    jes = call.get('jes', {})
    machine_type = jes.get('machineType')
    if machine_type:
        inferred_cpu, inferred_mem = infer_machine_cpu_mem(machine_type)
        cpu = cpu or inferred_cpu
        memory_gb = memory_gb or inferred_mem
    else:
        # Default fallback: 1 CPU, 4GB
        cpu = cpu or 1
        memory_gb = memory_gb or (cpu * 4.0)
    return cpu, memory_gb, total_disk_gb, preemptible


def compute_runtime_hours(call: Dict[str, Any]) -> float:
    """Compute the runtime (in hours) of a Cromwell call."""
    start_str = call.get('start')
    if not start_str:
        return 0.0
    start_time = parse_iso8601(start_str)
    end_str = call.get('end')
    if end_str:
        end_time = parse_iso8601(end_str)
    else:
        # Use current UTC time if call has not finished
        end_time = datetime.now(timezone.utc)
    duration_seconds = (end_time - start_time).total_seconds()
    # Enforce at least 1 minute minimum billable time
    hours = max(duration_seconds, 60) / 3600.0
    return hours


def calculate_call_cost(
    cpu: int,
    memory_gb: float,
    disk_gb: float,
    runtime_hours: float,
    preemptible: bool,
    rates: Dict[str, float],
) -> float:
    """Compute the cost of a single call given resource usage and rates."""
    if preemptible:
        cpu_cost = cpu * rates['cpu_preempt'] * runtime_hours
        mem_cost = memory_gb * rates['mem_preempt'] * runtime_hours
    else:
        cpu_cost = cpu * rates['cpu'] * runtime_hours
        mem_cost = memory_gb * rates['mem'] * runtime_hours
    # Disk cost applies regardless of preemptibility
    disk_cost = disk_gb * rates['disk'] * runtime_hours
    return cpu_cost + mem_cost + disk_cost


def flatten_calls(metadata: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Flatten the nested call structure in Cromwell metadata into a list of calls."""
    calls_list: List[Dict[str, Any]] = []
    for call_name, call_instances in metadata.get('calls', {}).items():
        for call in call_instances:
            call_copy = dict(call)  # shallow copy so we can annotate
            call_copy['callName'] = call_name
            calls_list.append(call_copy)
            # Recursively flatten subWorkflows
            if 'subWorkflowMetadata' in call:
                calls_list.extend(flatten_calls(call['subWorkflowMetadata']))
    return calls_list


def format_float(num: float, decimals: int = 2) -> str:
    return f"{num:.{decimals}f}"


def main() -> None:
    args = parse_arguments()
    metadata = load_metadata(args.metadata)
    # Pack rates into a dictionary for convenience
    rates = {
        'cpu': args.cpu_rate,
        'cpu_preempt': args.cpu_rate_preempt,
        'mem': args.mem_rate,
        'mem_preempt': args.mem_rate_preempt,
        'disk': args.disk_rate,
        'ssd': args.ssd_rate,
        'local_ssd': args.local_ssd_rate,
    }
    calls = flatten_calls(metadata)
    total_cost = 0.0
    rows = []
    for call in calls:
        cpu, mem_gb, disk_gb, preemptible = extract_resources(call)
        runtime_h = compute_runtime_hours(call)
        call_cost = calculate_call_cost(
            cpu,
            mem_gb,
            disk_gb,
            runtime_h,
            preemptible,
            rates,
        )
        total_cost += call_cost
        rows.append(
            {
                'name': call.get('callName', ''),
                'cpu': cpu,
                'memory_gb': mem_gb,
                'disk_gb': disk_gb,
                'hours': runtime_h,
                'preemptible': preemptible,
                'cost': call_cost,
            }
        )
    # Print details if requested
    if args.details:
        # Determine column widths
        header = [
            'Call', 'vCPUs', 'Memory (GB)', 'Disk (GB)', 'Hours', 'Preemptible', 'Cost ($)'
        ]
        # Build table
        print("\t".join(header))
        for row in rows:
            print(
                f"{row['name']}\t{row['cpu']}\t{format_float(row['memory_gb'])}\t"
                f"{format_float(row['disk_gb'])}\t{format_float(row['hours'])}\t"
                f"{row['preemptible']}\t{format_float(row['cost'])}"
            )
        print()
    print(f"Estimated total workflow cost: ${total_cost:.2f}")


if __name__ == '__main__':
    main()