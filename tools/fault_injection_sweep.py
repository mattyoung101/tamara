#!/usr/bin/env python3
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2025 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
from typing import List
import subprocess
import os
import argparse
import tempfile
import multiprocessing
import random
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style
import matplotlib.pyplot as plt
import matplotlib.ticker

# This script generates the graph of number of faults vs. % success
# The general method for running this tool is, from the TaMaRa build directory:
# ../tools/fault_injection_sweep.py --faults 10 --verilog ../tests/verilog/file.sv --top module --samples 30 --type protected --cleanup

# TYPST_TEMPLATE = """
# #figure(
#   image("../../diagrams/fault_{type}_{top}.svg", width: 80%),
#   caption: [ Fault injection study, {type} voter, `{top}` circuit ]
# ) <fig:fault_{type}_{top}>
# """
TYPST_TEMPLATE = """
    [
        {top}
    ],
    [
        #image("../../diagrams/fault_{type}_{top}.svg", width: 80%)
    ],
"""

DEBUG = False


def invoke(cmd: List[str]):
    # Custom feature from my Yosys fork that silences all 'show' commands. Can easily be replicated; see the
    # patch in tools/0001-Add-YS_IGNORE_SHOW-to-show.cc.patch
    os.environ["YS_IGNORE_SHOW"] = "1"
    os.environ["TAMARA_NO_DUMP"] = "1"
    # print(f"Running {cmd}")
    result = subprocess.run(cmd, capture_output=True, timeout=100)
    if DEBUG:
        print(result.stdout.decode("utf-8"))
    return result.returncode == 0


# Processes a single sample and returns either true for success or false for failure
def sample(verilog_path: str, top: str, num_faults: int, type_: str) -> bool:
    # read the script template file
    with open(f"../tests/formal/fault/nfaults_{type_}.ys.tmpl") as s:
        script_template = s.read()

    # apply template
    with tempfile.NamedTemporaryFile(prefix="tamara_script_") as f:
        f.write(
            script_template.format(
                faults=num_faults,
                script=verilog_path,
                top=top,
                seed=random.randint(0, 100000000),
            ).encode("utf-8")
        )
        f.flush()

        if invoke(["eqy", "-j", str(multiprocessing.cpu_count()), "-f", f.name]):
            return True
        else:
            return False


def main(faults: int, verilog_path: str, top: str, samples: int, type_: str):
    if "tamara/build" not in os.getcwd():
        raise RuntimeError("Must be run from tamara/build directory.")

    colorama_init()

    all_results = []

    # now inject 1..N faults
    for i in range(1, faults + 1):
        print(f"Testing with {i} faults... ", end="")

        # now invoke the script the number of sampled times
        success = 0
        failure = 0

        pool = multiprocessing.Pool()
        args = [[verilog_path, top, i, type_]] * samples
        results = pool.starmap(sample, args)

        for result in results:
            if result:
                success += 1
            else:
                failure += 1

        # green if >= 50% else red
        ratio = (success) / (success + failure)
        colour = Fore.GREEN if ratio >= 0.5 else Fore.RED

        print(
            f"{colour}Success: {ratio * 100:.2f}%{Style.RESET_ALL}"
        )

        all_results.append(ratio * 100)

    # plot results
    plt.figure(figsize=(8, 6), dpi=80)
    plt.plot(range(1, faults + 1), all_results, marker='o')  # Add dots with 'o' marker
    plt.xlabel("Number of faults")
    plt.ylabel("Mitigated faults (%)")
    plt.title(f"Fault injection study on '{top}', {type_} voter")
    plt.grid()

    # Force integer ticks on x-axis
    ax = plt.gca()
    ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True))

    print("Rendering figure...")
    plt.savefig(f"../papers/thesis/diagrams/fault_{type_}_{top}.svg", bbox_inches='tight')

    print("Typst code:")
    print(TYPST_TEMPLATE.format(type=type_, top=top))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--faults", help="Inject up to this many faults", type=int, required=True
    )
    parser.add_argument(
        "--verilog", help="Verilog file to test", type=str, required=True
    )
    parser.add_argument("--top", help="Top file in Verilog", type=str, required=True)
    parser.add_argument(
        "--samples", help="Number of simulations to run", type=int, required=True
    )
    parser.add_argument("--type", help="Protected or unprotected?", type=str, required=True)
    parser.add_argument(
        "--cleanup",
        help="Runs 'rm -rf tamara_script' in the current dir",
        action="store_true",
    )
    parser.add_argument(
        "--debug",
        help="Prints failure reason in run_eqy",
        action="store_true",
    )
    args = parser.parse_args()
    DEBUG = args.debug
    main(args.faults, args.verilog, args.top, args.samples, args.type)

    if args.cleanup:
        print("Cleaning up...")
        os.system("/usr/bin/bash -c 'rm -rf tamara_script*'")
