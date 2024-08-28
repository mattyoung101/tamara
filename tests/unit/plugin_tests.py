# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
# Copyright (c) 2024 Matt Young.
import unittest
import tempfile
import subprocess

# Unit tests for the TaMaRa plugin
# Ensure the latest binary is built first
# Run from the root directory of the TaMaRa git repo.


def start_yosys(script: str) -> str:
    # prepend the call to load libtamara
    script = "plugin -i build/libtamara.so\n" + script

    with tempfile.NamedTemporaryFile("w") as f:
        # write the script to a temporary location
        print(script, file=f)
        f.flush()

        # start Yosys
        result = subprocess.run(["yosys", "-s", f.name], timeout=540, check=True, capture_output=True)
        return result.stdout.decode("utf-8")


class TestTamaraPropagate(unittest.TestCase):
    def test_propagate_help(self):
        self.assertTrue("tamara_propagate" in start_yosys("help tamara_propagate"))

    def test_propagate_before_tmr(self):
        self.assertRaises(subprocess.CalledProcessError, start_yosys, "tamara_tmr")


if __name__ == '__main__':
    unittest.main()
