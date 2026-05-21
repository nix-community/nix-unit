#!/usr/bin/env python
from __future__ import annotations

import os
import os.path
import subprocess
from dataclasses import dataclass
from typing import (
    Dict,
    Optional,
    Union,
)


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


def run_suite(
    name: str,
    expected: dict[str, TestResult],
    flake: bool,
    extra_args: list[str] | None = None,
    strict: bool = False,
    expect_exit: int | None = None,
):
    extra_args = list(extra_args or [])
    if flake:
        cmd = [
            "nix",
            "run",
            "..",
            "--",
            "--flake",
            f"./assets#testSuites.{name}",
        ] + extra_args
    else:
        cmd = ["nix", "run", "..", "--", f"./assets/{name}.nix"] + extra_args
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    if expect_exit is not None and proc.returncode != expect_exit:
        raise ValueError(
            f"unexpected exit {proc.returncode} (want {expect_exit}) for {cmd}\n"
            f"stdout: {proc.stdout.decode()}\n"
            f"stderr: {proc.stderr.decode()}"
        )

    results: dict[str, TestResult] = {}
    get_output_structured(proc.stdout.decode(), results)
    get_output_structured(proc.stderr.decode(), results)

    if strict and set(results.keys()) != set(expected.keys()):
        raise ValueError(
            f"result names {sorted(results.keys())} != expected {sorted(expected.keys())}\n"
            f"stdout: {proc.stdout.decode()}\n"
            f"stderr: {proc.stderr.decode()}"
        )

    for test, expected_result in expected.items():
        if test not in results:
            raise ValueError(
                f"missing test result {test!r}; got {sorted(results.keys())}"
            )
        result = results[test]
        if result != expected_result:
            raise ValueError(f"{result} != {expected_result}")


def run_attr_path_error(name: str, attr: str, flake: bool, needle: str):
    """Invoke nix-unit with an invalid -A and assert it fails with `needle` in stderr."""
    if flake:
        cmd = [
            "nix",
            "run",
            "..",
            "--",
            "--flake",
            f"./assets#testSuites.{name}",
            "-A",
            attr,
        ]
    else:
        cmd = ["nix", "run", "..", "--", f"./assets/{name}.nix", "-A", attr]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode == 0:
        raise ValueError(
            f"expected failure for {cmd}, got exit 0\nstderr: {proc.stderr.decode()}"
        )
    stderr = proc.stderr.decode()
    if needle not in stderr:
        raise ValueError(f"stderr missing {needle!r} for {cmd}\nstderr: {stderr}")


def group_expected(*results: TestResult) -> Dict[str, TestResult]:
    return {result.name: result for result in results}


suites = {
    "basic": group_expected(
        TestResult("nested.testFoo", success=True),
        TestResult("testPass", success=True),
        TestResult("testFail", fail=True),
        TestResult("testFailEval", eval_fail=True),
        TestResult("testFailMissingError", eval_fail=True),
        TestResult("testCatchThrow", success=True),
        TestResult("testCatchAbort", success=True),
        TestResult("testCatchAssertionError", success=True),
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
            nix flake check --no-update-lock-file \
              --no-write-lock-file \
              --extra-experimental-features "nix-command flakes" \
              --override-input nix-unit "$NIX_UNIT_OUTPATH" \
              --reference-lock-file "$NIX_UNIT_OUTPATH/flake.lock" \
              .
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

    # -A subtree entry point runs only tests inside that subtree.
    print("Testing: -A nested")
    run_suite(
        "basic",
        group_expected(TestResult("nested.testFoo", success=True)),
        flake=False,
        extra_args=["-A", "nested"],
        strict=True,
        expect_exit=0,
    )
    run_suite(
        "basic",
        group_expected(TestResult("nested.testFoo", success=True)),
        flake=True,
        extra_args=["-A", "nested"],
        strict=True,
        expect_exit=0,
    )

    # -A run as a single test.
    print("Testing: -A nested.testFoo")
    run_suite(
        "basic",
        group_expected(TestResult("nested.testFoo", success=True)),
        flake=False,
        extra_args=["-A", "nested.testFoo"],
        strict=True,
        expect_exit=0,
    )

    # -A accept multiple
    print("Testing: -A testPass -A testCatchThrow")
    run_suite(
        "basic",
        group_expected(
            TestResult("testPass", success=True),
            TestResult("testCatchThrow", success=True),
        ),
        flake=False,
        extra_args=["-A", "testPass", "-A", "testCatchThrow"],
        strict=True,
        expect_exit=0,
    )

    # -A failures produce non-zero exit.
    print("Testing: -A testFail (failure exit)")
    run_suite(
        "basic",
        group_expected(TestResult("testFail", fail=True)),
        flake=False,
        extra_args=["-A", "testFail"],
        strict=True,
        expect_exit=1,
    )

    # -A missing path
    print("Testing: -A nope (missing path)")
    run_attr_path_error("basic", "nope", flake=False, needle="'nope' in selection path")

    # -A on a non-attrset value
    print("Testing: -A testPass.expr (non-attrset, non-test leaf)")
    run_attr_path_error(
        "basic",
        "testPass.expr",
        flake=False,
        needle="is not an attrset",
    )

    run_flake_checks()
