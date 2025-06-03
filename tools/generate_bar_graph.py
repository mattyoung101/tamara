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

# This script generates a bar graph comparing the unprotected vs. unmitigated results for a bunch of circuits

TYPST_TEMPLATE = """
#figure(
    image("../../diagrams/{out}", width: 80%),
    caption: [ Caption ]
)
"""


def circuits(contents: str, out: Optional[str]):
    individual = contents.split(",")
    print(f"Generate multiple circuits for {individual}")

    results_dir = Path("../papers/thesis/results")

    # plot results
    plt.figure(figsize=(8, 6), dpi=80)
    plt.xlabel("Number of faults")
    plt.ylabel("Difference (%)")
    plt.title("Difference in mitigated faults")
    plt.grid()
    plt.ylim(0, 100)

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
    circuits(args.circuits, args.out)
