#!/usr/bin/env python3
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2025 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Generates a truth table for an N-bit voter
import sys

file = sys.argv[1]

with open(file, "r") as f:
    for line in f.readlines():
        print(f"log(\"{line.strip()}\\n\");")
