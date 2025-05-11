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

# This script uses the outputs written by "fault_injection_sweep.py" to build multi-graphs of the results.


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
    DEBUG = args.debug
