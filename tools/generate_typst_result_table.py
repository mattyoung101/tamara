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

SCRIPT_TEMPLATE = """
read_verilog -sv {verilog_path}
prep -top {top}
show -colors 420 -format svg -prefix ../papers/thesis/diagrams/schematics/{top}
"""

# This script generates the result table in Typst


def invoke(cmd: List[str]):
    os.environ["TAMARA_NO_DUMP"] = "1"
    output = subprocess.check_output(cmd, timeout=100)
    print(output.decode("utf-8"))


def main(verilog_path: str, top: str):
    if "tamara/build" not in os.getcwd():
        raise RuntimeError("Must be run from tamara/build directory.")

    colorama_init()

    # apply template
    print(f"{Fore.CYAN}Processing script{Style.RESET_ALL}")
    with tempfile.NamedTemporaryFile(prefix="tamara_script_") as f:
        # print(script.format(faults=i))
        f.write(SCRIPT_TEMPLATE.format(verilog_path=verilog_path, top=top).encode("utf-8"))
        f.flush()

        invoke(["yosys", "-s", f.name])

    with open(verilog_path) as f:
        verilog_contents = f.read()

    # write result to stdout
    print("""
    [
        {top_escaped}
    ],
    [
        ```systemverilog
{verilog_contents}
        ```
    ],
    [
        #image("../../diagrams/schematics/{top}.svg")
    ],
    """.format(
        top=top,
        top_escaped=top.replace("_", "\\_"),
        verilog_contents=verilog_contents
    )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verilog", help="Verilog file to test", type=str, required=True)
    parser.add_argument("--top", help="Top file in Verilog", type=str, required=True)
    args = parser.parse_args()
    main(args.verilog, args.top)
