#!/usr/bin/env python
from __future__ import annotations
from dataclasses import dataclass
from typing import (
    Optional,
    Union,
    Dict,
)
import subprocess
import os.path
import os


@dataclass
class TestResult:
    name: str

    eval_fail: Optional[bool] = None
    fail: Optional[bool] = None
    success: Optional[bool] = None

    output: Optional[Union[str, list[str]]] = None

    def __eq__(self, rhs: TestResult) -> bool:
        if self.name != rhs.name:
            return False

        if rhs.eval_fail is not None and rhs.eval_fail != self.eval_fail:
            return False

        if rhs.fail is not None and rhs.fail != self.fail:
            return False

        if rhs.success is not None and rhs.success != self.success:
            return False

        if rhs.output is not None:
            if isinstance(rhs.output, list):
                for o in rhs.output:
                    if o not in self.output:  # type: ignore
                        return False
            else:
                if rhs.output not in self.output:  # type: ignore
                    return False

        return True


def get_output_structured(stream: str, results: Dict[str, TestResult]):
    """Returns the nix-unit output as a structured dict"""
    lines = stream.splitlines()

    for idx, line in enumerate(lines):
        if line.startswith("✅") or line.startswith("❌") or line.startswith("☢️"):
            output_sym, name = line.split()
            results[name] = TestResult(
                name,
                eval_fail=output_sym == "☢️",
                fail=output_sym == "❌",
                success=output_sym == "✅",
            )


def run_suite(name: str, expected: Dict[str, TestResult], flake: bool):
    if flake:
        proc = subprocess.run(
            ["nix", "run", "..", "--", "--flake", f"./assets#testSuites.{name}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    else:
        proc = subprocess.run(
            ["nix", "run", "..", "--", f"./assets/{name}.nix"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    results = {}
    get_output_structured(proc.stdout.decode(), results)
    get_output_structured(proc.stderr.decode(), results)

    for test, expected_result in expected.items():
        # from pprint import pprint
        # pprint(results)
        result = results[test]
        if results[test] != expected_result:
            raise ValueError(f"{result} != {expected_result}")


def group_expected(*results: TestResult) -> Dict[str, TestResult]:
    return {result.name: result for result in results}


suites = {
    "basic": group_expected(
        TestResult("nested.testFoo", success=True),
        TestResult("testPass", success=True),
        TestResult("testFail", fail=True),
        TestResult("testFailEval", eval_fail=True),
        TestResult("testCatchThrow", success=True),
        TestResult("testCatchAbort", success=True),
        TestResult("testCatchMessage", success=True),
        TestResult("testCatchThrow", success=True),
        TestResult("testCatchAbort", success=True),
        TestResult("testCatchMessage", success=True),
        TestResult("testCatchWrongMessage", fail=True),
    ),
}


def run_flake_checks():
    print("Testing: flake checks")

    proc = subprocess.run(
        [
            "bash",
            "-c",
            """
            cd ../lib/flake-checks
            nix flake check \
              --no-write-lock-file \
              --extra-experimental-features "nix-command flakes" \
              --override-input nix-unit "$NIX_UNIT_OUTPATH"
         """,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    if proc.stderr.find(pattern := "0/1 successful") == -1:
        raise ValueError(f"output: {proc.stderr}\n\ndoesn't contain {pattern=}")


if __name__ == "__main__":
    test_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(test_dir)

    for suite, expected in suites.items():
        print(f"Testing: {suite}")
        run_suite(suite, expected, flake=False)

        print(f"Testing: {suite} (flake)")
        run_suite(suite, expected, flake=True)

    run_flake_checks()
