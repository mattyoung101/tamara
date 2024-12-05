#!/usr/bin/env python3
# Generates a truth table for an N-bit voter
import itertools
from collections import Counter

BITS = 2

for i, binary in enumerate(itertools.product((0, 1), (0, 1), (0, 1), repeat=BITS)):
    # We need to vote independently on each bit
    # TODO: partition the list into a group of 3 * N bits
    pass
