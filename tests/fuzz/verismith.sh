#!/bin/bash
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2024 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

dir=$(pwd)

if [[ $dir != *tamara/build ]] then
    echo "ERROR: verismith.sh must be run from the tamara/build directory. You are in: $dir"
    exit 1
fi

# Number of test cases to run
TESTS=4096
UUID=$(date +%Y-%m-%d-%H-%M.%S)
VERISMITH_DIR=verismith_out/$UUID

echo "Making temp dir in $VERISMITH_DIR..."
mkdir -p $VERISMITH_DIR

# Run verismith to generate bulk Verilog files in parallel
echo "Generating data..."
seq -w 0 $TESTS | parallel --progress ./verismith generate --config ../tests/fuzz/tiny.toml ">" $VERISMITH_DIR/{}.v

# Run TaMaRa in parallel and capture failures
echo "Running TaMaRa..."
# Redirect errors using parallel, so that we capture ASan output as well
find $VERISMITH_DIR -type f | parallel --progress --results {}.log "yosys -p \"read_verilog {}; script ../tests/scripts/verismith.ys\""

echo "Deleting non-error logs..."
for base in $(seq -w 0 $TESTS); do
    if [ ! -s $VERISMITH_DIR/$base.v.log.err ]; then
        # empty error log -> delete
        rm $VERISMITH_DIR/$base.*
    else
        echo "Error found! $VERISMITH_DIR/$base:"
        cat $VERISMITH_DIR/$base.v.log.err
        echo ""
        echo ""
    fi
done

echo "Done."
