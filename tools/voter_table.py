#!/usr/bin/env python3
# Generates a truth table for an N-bit voter
import itertools

BITS = 4
CHUNKS = ["A", "B", "C"]

# These functions are taken from voter.sv


def majority(a: bool, b: bool, c: bool) -> bool:
    return (a and b) or (b and c) or (a and c)


def error(a: bool, b: bool, c: bool) -> bool:
    return (not a and c) or (a and not b) or (b and not c)

# Write out in Logisim table format


banner = f"a[{BITS - 1}..0] b[{BITS - 1}..0] c[{BITS - 1}..0] | outt[{BITS - 1}..0] err"
print(banner)
print("~" * len(banner))

for i, binary in enumerate(itertools.product((0, 1), (0, 1), (0, 1), repeat=BITS)):
    # a single item in the header
    single = f"a[{BITS - 1}..0]"

    # each "chunk" is an N-bit value for either A, B or C for the voter input
    inputs = {}
    print(" ", end="")
    for j, chunk in enumerate(itertools.batched(binary, BITS)):
        chunk_name = CHUNKS[j]
        inputs[chunk_name] = chunk

        print("".join([str(x) for x in chunk]), end="")
        if j != BITS:
            print(" " * len(single), end="")

    print("   | ", end="")

    # now we need to vote on each bit independently
    out = {}
    did_error_occur = False
    for bit in range(BITS):
        a = bool(inputs["A"][bit])
        b = bool(inputs["B"][bit])
        c = bool(inputs["C"][bit])

        # vote independently on each bit
        out[bit] = int(majority(a, b, c))

        # if an error occurred anywhere, mark it
        if error(a, b, c):
            did_error_occur = True

    # display out
    for bit in range(BITS):
        print(str(out[bit]), end="")
    print(" " * len(single) + " ", end="")

    # display error
    print(f" {int(did_error_occur)}")
