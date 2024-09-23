#!/bin/bash
set -e
dir=$(pwd)

if [[ $dir != *tamara/build ]]
then
    echo "ERROR: test.sh must be run from the tamara/build directory. You are in: $dir"
    exit 1
fi

echo "Run formal equivalence checking tests..."
for filename in ../tests/formal/equivalence/*.eqy; do
    echo "Run eqy: $filename"
    eqy -f $filename
done

echo "Check scripts do not crash Yosys..."
for filename in ../tests/scripts/*.ys; do
    echo "Run Yosys: $filename"
    yosys $filename
done

echo -e "\n\nOK!\n\n"
