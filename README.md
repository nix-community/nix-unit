# nix-unit

This project runs an attribute set of tests compatible with `lib.debug.runTests` while allowing individual attributes to fail.

## Why use nix-unit?

- Compatible with `lib.debug.runTests`

If your tests follows the structure used by `runTests` adoption of `nix-unit` is easy.

- Allows individual test attributes to fail individually.

Rather than evaluating the entire test suite in one go, serialise & compare `nix-unit` uses the Nix evaluator, meaning it can fail tests individually.
We can catch individual attributes evaluation failures.

## Comparison with other tools
This comparison matrix was originally taken from [Unit test your Nix code](https://www.tweag.io/blog/2022-09-01-unit-test-your-nix-code/) but has been adapted.

| Tool        | Can test eval failures | Tests are defined in Nix | Maintained |
| ----------- | ---------------------- | ------------------------ | ---------- |
| Nix-unit    | yes                    | yes                      | yes        |
| runTests    | no                     | yes                      | yes        |
| Pythonix    | yes                    | no                       | no         |
| Nixt        | no                     | yes                      | yes        |

## Example output

An expression called `test.nix` containing:
``` nix
{
  pass = {
    expr = 1;
    expected = 1;
  };

  fail = {
    expr = 1;
    expected = 0;
  };

  failEval = {
    expr = throw "NO U";
    expected = 0;
  };
}
```

Results in the output:
```
❌ fail
1 != 0

☢️ failEval
error:
       … while calling the 'throw' builtin

         at .../nix-unit/test.nix:13:12:

           12|   failEval = {
           13|     expr = throw "NO U";
             |            ^
           14|     expected = 0;

       error: NO U

✅ pass

😢 1/3 successful
error: Tests failed
```
