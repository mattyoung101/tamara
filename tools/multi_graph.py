#!/usr/bin/env python3
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2025 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
import argparse
import matplotlib.pyplot as plt
import matplotlib.ticker
import json
from pathlib import Path
from typing import Optional

# This script uses the outputs written by "fault_injection_sweep.py" to build multi-graphs of the results.
# Must be run from build dir.
TYPST_TEMPLATE = """
#figure(
    image("../../diagrams/{out}", width: 80%),
    caption: [ Caption ]
)
"""


def circuit(name: str, is_prot: bool, is_unprot: bool, is_unmit: bool, out: Optional[str]):
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
    if out is not None:
        plt.savefig(f"../papers/thesis/diagrams/{out}", bbox_inches='tight', transparent=True)
        print(TYPST_TEMPLATE.format(out=out))
    plt.show()


def circuits(contents: str, mode: str, out: Optional[str]):
    individual = contents.split(",")
    print(f"Generate multiple circuits for {individual} with mode {mode}")

    results_dir = Path("../papers/thesis/results")

    # plot results
    plt.figure(figsize=(8, 6), dpi=80)
    plt.xlabel("Number of faults")
    plt.ylabel("Mitigated faults (%)")
    plt.title(f"Multi-fault injection study for {len(individual)} circuits")
    plt.grid()

    # Force integer ticks on x-axis
    ax = plt.gca()
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))

    for name in individual:
        data = json.loads((results_dir / f"fault_{mode}_{name}.json").read_text())
        plt.plot(data["faults"], data["results"], marker='o', label=name)

    plt.legend()
    if out is not None:
        plt.savefig(f"../papers/thesis/diagrams/{out}", bbox_inches='tight', transparent=True)
        print(TYPST_TEMPLATE.format(out=out))
    plt.show()


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
    parser.add_argument(
        "--out",
        help="If specified, write out to thesis graph dir with this SVG file and print Typst code"
    )

    args = parser.parse_args()

    if args.circuit is not None and args.circuits is not None:
        raise RuntimeError("Cannot specify both --circuit and --circuits")

    if args.circuit:
        circuit(args.circuit, args.prot, args.unprot, args.unmit, args.out)
    elif args.circuits:
        all = [args.prot, args.unprot, args.unmit]
        if len([x for x in all if x]) != 1:
            raise RuntimeError("Only exactly one of --prot, --unprot or --unmit may be specified with --circuits")

        if args.prot:
            mode = "protected"
        elif args.unprot:
            mode = "unprotected"
        elif args.unmit:
            mode = "unmitigated"
        circuits(args.circuits, mode, args.out)
