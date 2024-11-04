#!/bin/bash
# set -e
dir=$(pwd)

if [[ $dir != *tamara/build ]]
then
    echo "ERROR: verismith.sh must be run from the tamara/build directory. You are in: $dir"
    exit 1
fi

# Number of test cases to run
TESTS=1000
UUID=$(uuid)
VERISMITH_DIR=/tmp/verismith/$UUID

echo "Making temp dir in $VERISMITH_DIR..."
mkdir -p $VERISMITH_DIR

# Run verismith to generate bulk Verilog files in parallel
echo "Generating data..."
seq -w 0 $TESTS | parallel --progress ./verismith generate ">" $VERISMITH_DIR/{}.v

# Prepend (* tamara_triplicate *) to each file
echo "Prepending (* tamara_triplicate *) annotation..."
for filename in $VERISMITH_DIR/*.v; do
    printf '%s\n%s\n' "(* tamara_triplicate *)" "$(cat $filename)" > $filename
done

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
