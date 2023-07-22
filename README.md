# nix-unit

This project runs an attribute set of tests compatible with `lib.debug.runTests` while allowing individual attributes to fail.

![](./.github/demo.gif)


## Why use nix-unit?

- Compatible with `lib.debug.runTests`

If your tests follows the structure used by `runTests` adoption of `nix-unit` is easy.

- Allows individual test attributes to fail individually.

Rather than evaluating the entire test suite in one go, serialise & compare `nix-unit` uses the Nix evaluator C++ API.
Meaning that we can catch test failures individually, even if the failure is caused by an evaluation error.

## Comparison with other tools
This comparison matrix was originally taken from [Unit test your Nix code](https://www.tweag.io/blog/2022-09-01-unit-test-your-nix-code/) but has been adapted.
Pythonix is excluded as it's unmaintained.

| Tool        | Can test eval failures | Tests defined in Nix | in nixpkgs | snapshot testing(1) |
| ----------- | ---------------------- | -------------------- | ---------- |-------------------- |
| Nix-unit    | yes                    | yes                  | no         | no                  |
| runTests    | no                     | yes                  | yes        | no                  |
| Nixt        | no                     | yes                  | no         | no                  |
| Namaka      | no                     | yes                  | yes        | yes                 |

1. [Snapshot testing](https://github.com/nix-community/namaka#snapshot-testing)

## Example output

An expression called `test.nix` containing:
``` nix
{
  testPass = {
    expr = 1;
    expected = 1;
  };

  testFail = {
    expr = { x = 1; };
    expected = { y = 1; };
  };

  testFailEval = {
    expr = throw "NO U";
    expected = 0;
  };
}
```

Results in the output:
```
❌ testFail
{ x = 1; } != { y = 1; }

☢️ testFailEval
error:
       … while calling the 'throw' builtin

         at /home/adisbladis/nix-eval-jobs/test.nix:13:12:

           12|   testFailEval = {
           13|     expr = throw "NO U";
             |            ^
           14|     expected = 0;

       error: NO U

✅ testPass

😢 1/3 successful
error: Tests failed
```
