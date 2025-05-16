#!/usr/bin/env python3
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2025 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
import argparse
import random
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style
import matplotlib.pyplot as plt
import matplotlib.ticker
import json
from datetime import datetime
import hashlib
from pathlib import Path

# This script uses the outputs written by "fault_injection_sweep.py" to build multi-graphs of the results.
# Must be run from build dir.


def circuit(name: str, is_prot: bool, is_unprot: bool, is_unmit: bool):
    print(f"Generate single circuit graph for {name} with prot={is_prot}, unprot={is_unprot}, unmit={is_unmit}")

    results_dir = Path("../papers/thesis/results")

    # plot results
    plt.figure(figsize=(8, 6), dpi=80)
    plt.xlabel("Number of faults")
    plt.ylabel("Mitigated faults (%)")
    plt.title(f"Multi-fault injection study on {name}")
    plt.grid()

    # Force integer ticks on x-axis
    ax = plt.gca()
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))

    if is_prot:
        data = json.loads((results_dir / f"fault_protected_{name}.json").read_text())
        plt.plot(data["faults"], data["results"], marker='o', label="Protected voter")

    if is_unprot:
        data = json.loads((results_dir / f"fault_unprotected_{name}.json").read_text())
        plt.plot(data["faults"], data["results"], marker='o', label="Unprotected voter")

    if is_unmit:
        data = json.loads((results_dir / f"fault_unmitigated_{name}.json").read_text())
        plt.plot(data["faults"], data["results"], marker='o', label="Unmitigated circuit")

    plt.legend()
    plt.savefig("/tmp/multifault.svg",bbox_inches='tight', transparent=True)
    plt.show()


def circuits(contents: str):
    individual = contents.split(",")
    raise RuntimeError("Not yet implemented")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--prot",
        help="Include protected result",
        action="store_true",
    )
    parser.add_argument(
        "--unprot",
        help="Include unprotected result",
        action="store_true",
    )
    parser.add_argument(
        "--unmit",
        help="Include unmitigated result",
        action="store_true",
    )
    parser.add_argument(
        "--circuit",
        help=(
            "Path to circuit to use. Mutually exclusive with --circuits. If "
            "this is specified, we'll plot a prot, unprot and unmit for a single circuit."
        ),
        type=str,
    )

    parser.add_argument(
        "--circuits",
        help=(
            "Path to multiple circuits to use. Mutually exclusive with"
            "--circuit. If this is specified, we'll plot ONE of prot, unprot and unmit for"
            "multiple circuits "
        ),
        type=str,
    )
    args = parser.parse_args()

    if args.circuit is not None and args.circuits is not None:
        raise RuntimeError("Cannot specify both --circuit and --circuits")

    if args.circuit:
        circuit(args.circuit, args.prot, args.unprot, args.unmit)

    elif args.circuits:
        circuits()
