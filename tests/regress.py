#!/usr/bin/env python3
# TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
#
# Copyright (c) 2025 Matt Young.
#
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
import yaml
from typing import List
from colorama import init as colorama_init
from colorama import Fore
from colorama import Style
import subprocess
import shlex
import os
from yaspin import yaspin
from datetime import datetime
import json

# This script runs a regression test, based on the scripts listed in regress.yaml
# Must be run from the build dir, like: ../tests/regress.py

passed = 0
failed = 0
failed_tests = []


def invoke(cmd: List[str]):
    global passed, failed, failed_tests
    # Custom feature from my Yosys fork that silences all 'show' commands. Can easily be replicated through
    # this patch:

    # diff --git a/passes/cmds/show.cc b/passes/cmds/show.cc
    # index 82b5c6bcf..b1d644249 100644
    # --- a/passes/cmds/show.cc
    # +++ b/passes/cmds/show.cc
    # @@ -20,6 +20,7 @@
    #  #include "kernel/register.h"
    #  #include "kernel/celltypes.h"
    #  #include "kernel/log.h"
    # +#include <cstdlib>
    #  #include <string.h>
    #
    #  #ifndef _WIN32
    # @@ -752,6 +753,10 @@ struct ShowPass : public Pass {
    #         }
    #         void execute(std::vector<std::string> args, RTLIL::Design *design) override
    #         {
    # +               if (getenv("YS_IGNORE_SHOW") != nullptr) {
    # +                       return;
    # +               }
    # +
    #             log_header(design, "Generating Graphviz representation of design.\n");
    #             log_push();

    os.environ["YS_IGNORE_SHOW"] = "1"
    result = subprocess.run(cmd, capture_output=True, timeout=100)

    if result.returncode == 0:
        print(f"{Fore.GREEN}OK{Style.RESET_ALL}")
        passed += 1
    else:
        print(f"{Fore.RED}FAIL{Style.RESET_ALL}\nRan:"
              f"{shlex.join(cmd)}\n{result.stdout.decode('utf-8')}\n{result.stderr.decode('utf-8')}")
        failed += 1
        failed_tests.append(shlex.join(cmd))


def run_eqy_tests(tests: List[str]):
    for test in tests:
        print(f"{Fore.BLUE}Running eqy test: {test}{Style.RESET_ALL}... ", end="", flush=True)
        invoke(["eqy", "-f", f"../tests/formal/equivalence/{test}.eqy"])


def run_script_tests(tests: List[str]):
    for test in tests:
        print(f"{Fore.BLUE}Running script test: {test}{Style.RESET_ALL}... ", end="", flush=True)
        invoke(["yosys", f"../tests/scripts/{test}.ys"])


def main():
    if "tamara/build" not in os.getcwd():
        raise RuntimeError("Must be run from tamara/build directory.")

    colorama_init()
    print(f"{Fore.CYAN}Running TaMaRa regression pipeline{Style.RESET_ALL}\n")

    with yaspin(text="Building..."):
        invoke(["cmake", "--build", "."])
        print("")

    with open("../tests/regress.yaml") as f:
        doc = yaml.safe_load(f)
        run_eqy_tests(doc["eqy"])
        run_script_tests(doc["scripts"])

    print(f"{Fore.LIGHTGREEN_EX}{passed} passed{Style.RESET_ALL} {Fore.RED}{failed} failed{Style.RESET_ALL}")
    print(f"{Fore.CYAN}{int(round((passed / (passed + failed) * 100.0)))}% success{Style.RESET_ALL}")

    if failed > 0:
        print(f"\n{Fore.RED}Failed tests:{Style.RESET_ALL}")
        for test in failed_tests:
            print(f"- {test}")

    # is there a prior result? if so, we can see if we regressed
    try:
        # load the prior result
        with open("tamara-regress-latest.txt") as latest_f:
            latest = latest_f.readline().strip()
            with open(latest) as f:
                prior_result = json.load(f)

                # if it's the same number of tests, we can determine if there was a regression
                if prior_result["passed"] + prior_result["failed"] == passed + failed:
                    if failed > prior_result["failed"]:
                        print(f"\n{Fore.RED + Style.BRIGHT}⚠️ ⚠️ YOU HAVE REGRESSED! ⚠️ ⚠️{Style.RESET_ALL}")
                        print(f"\nTest {latest} had {prior_result['failed']} failed tests, which is"
                              f" {failed - prior_result['failed']} less than you have now.\n")
                    else:
                        print(f"\n{Fore.GREEN}You have not regressed :){Style.RESET_ALL}")
                else:
                    print(f"\nA prior test, {latest}, could not be used because it has a differing test count"
                          " to the current test suite.\n")
    except FileNotFoundError:
        print("\nNo prior regression test suite exists.\n")

    # write result to disk
    date = datetime.now().strftime("%Y-%d-%H-%M-%S.%f")
    result = {
        "passed": passed,
        "failed": failed
    }
    with open(f"tamara-regress-{date}.json", "w") as f:
        json.dump(result, f)

    # update link to latest
    with open("tamara-regress-latest.txt", "w") as f:
        print(f"tamara-regress-{date}.json", file=f)


if __name__ == "__main__":
    main()
