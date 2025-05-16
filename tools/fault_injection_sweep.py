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
import json
from datetime import datetime
import hashlib

# This script generates the graph of number of faults vs. % success.
# Must be run from build dir.
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


def sha256sum(filename):
    with open(filename, 'rb', buffering=0) as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def invoke(cmd: List[str]):
    # Custom feature from my Yosys fork that silences all 'show' commands. Can easily be replicated; see the
    # patch in tools/0001-Add-YS_IGNORE_SHOW-to-show.cc.patch
    os.environ["YS_IGNORE_SHOW"] = "1"
    os.environ["TAMARA_NO_DUMP"] = "1"
    # print(f"Running {cmd}")
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,  # Redirect stderr into stdout
            timeout=120
        )

        if DEBUG and result.returncode != 0:
            print(f"{cmd} failed!")
            print(result.stdout.decode("utf-8"))

        return result.returncode == 0
    except subprocess.TimeoutExpired:
        # timeouts count as failures
        print("Warning: Timed out!")
        return 0


# Processes a single sample and returns either true for success or false for failure
def sample(verilog_path: str, top: str, num_faults: int, type_: str, executor: str) -> bool:
    if executor == "ys" or executor == "yosys":
        path = f"../tests/formal/fault/nfaults_{type_}.ys.tmpl"
    elif executor == "eqy":
        path = f"../tests/formal/fault/eqy/nfaults_{type_}.eqy.tmpl"
    else:
        raise RuntimeError(f"Invalid executor {executor}")

    # read the script template file
    with open(path) as s:
        script_template = s.read()

    # apply template
    with tempfile.NamedTemporaryFile(prefix="tamara_script_", delete=False) as f:
        with tempfile.NamedTemporaryFile(prefix="tamara_mutate_") as mutate_script:
            f.write(
                script_template.format(
                    faults=num_faults,
                    script=verilog_path,
                    top=top,
                    seed=random.randint(0, 100000000),
                    mutate_script=mutate_script.name
                ).encode("utf-8")
            )
            f.flush()

            if executor == "yosys" or executor == "ys":
                args = ["yosys", "-s", f.name]
            elif executor == "eqy":
                args = ["eqy", "-j", str(multiprocessing.cpu_count()), "-f", f.name]
            else:
                raise RuntimeError(f"Invalid executor {executor}")

            if invoke(args):
                # it works so we can delete it
                os.unlink(f.name)
                return True
            else:
                if DEBUG:
                    print(f"{f.name} failed!")
                    # don't unlink in debug mode
                else:
                    os.unlink(f.name)
                return False


def main(faults: int, verilog_path: str, top: str, samples: int, type_: str, no_write: bool, executor: str):
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
        args = [[verilog_path, top, i, type_, executor]] * samples
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

    if no_write:
        return

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

    path = f"../papers/thesis/results/fault_{type_}_{top}.json"
    print(f"Dumping JSON to {path}")
    with open(path, "w") as f:
        json.dump({
            "faults": list(range(1, faults + 1)),
            "results": all_results,
            "date": str(datetime.now().astimezone()),
            "verilog_file_hash": sha256sum(verilog_path),
            "num_faults": faults,
            "verilog_path": verilog_path,
            "top": top,
            "samples": samples,
            "type_": type_
        }, f, indent=4)

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
    parser.add_argument("--type", help="'protected', 'unprotected', or 'unmitigated'", type=str, required=True)
    parser.add_argument(
        "--debug",
        help="Prints failure reason in run_eqy",
        action="store_true",
    )
    parser.add_argument(
        "--nowrite",
        help="Do not write output files",
        action="store_true"
    )
    parser.add_argument("--executor", help="Use Yosys SAT or eqy? (ys/eqy)", type=str, default="ys")
    args = parser.parse_args()
    DEBUG = args.debug

    main(args.faults, args.verilog, args.top, args.samples, args.type, args.nowrite, args.executor)

    if args.executor == "eqy":
        print("Cleaning up eqy junk...")
        os.system("/usr/bin/bash -c 'rm -rf tamara_script*'")
