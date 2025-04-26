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
from typing import Tuple

# This script generates the graph of number of faults vs. % success


def invoke(cmd: List[str]):
    # Custom feature from my Yosys fork that silences all 'show' commands. Can easily be replicated; see the
    # patch in tools/0001-Add-YS_IGNORE_SHOW-to-show.cc.patch
    os.environ["YS_IGNORE_SHOW"] = "1"
    os.environ["TAMARA_NO_DUMP"] = "1"
    # print(f"Running {cmd}")
    result = subprocess.run(cmd, capture_output=True, timeout=100)
    # print(result.stdout.decode("utf-8"))
    return result.returncode == 0


# Processes a single sample and returns either true for success or false for failure
def sample(verilog_path: str, top: str, num_faults: int) -> bool:
    # read the script template file
    with open("../tests/formal/fault/nfaults.ys.tmpl") as s:
        script_template = s.read()

    # apply template
    with tempfile.NamedTemporaryFile(prefix="tamara_script_") as f:
        f.write(script_template.format(faults=num_faults, script=verilog_path, top=top, seed=random.randint(0, 100000000)).encode("utf-8"))
        f.flush()

        if invoke(["eqy", "-j", str(multiprocessing.cpu_count()), "-f", f.name]):
            return True
        else:
            return False


def main(faults: int, verilog_path: str, top: str, samples: int):
    if "tamara/build" not in os.getcwd():
        raise RuntimeError("Must be run from tamara/build directory.")

    colorama_init()

    # now inject 1..N faults
    for i in range(1, faults + 1):
        print(f"Testing with {i} faults... ", end="")

        # now invoke the script the number of sampled times
        success = 0
        failure = 0

        pool = multiprocessing.Pool()
        args = [[verilog_path, top, i]] * samples
        results = pool.starmap(sample, args)

        for result in results:
            if result:
                success += 1
            else:
                failure += 1

        # green if >= 50% else red
        colour = Fore.GREEN if ((success) / (success + failure)) >= 0.5 else Fore.RED

        print(f"{colour}Success: {((success) / (success + failure)) * 100:.2f}%{Style.RESET_ALL}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--faults", help="Inject up to this many faults", type=int, required=True)
    parser.add_argument("--verilog", help="Verilog file to test", type=str, required=True)
    parser.add_argument("--top", help="Top file in Verilog", type=str, required=True)
    parser.add_argument("--samples", help="Number of simulations to run", type=int, required=True)
    parser.add_argument("--cleanup", help="Runs 'rm -rf tamara_script' in the current dir", action="store_true")
    args = parser.parse_args()
    main(args.faults, args.verilog, args.top, args.samples)

    if args.cleanup:
        print("Cleaning up...")
        os.system("/usr/bin/bash -c 'rm -rf tamara_script*'")
