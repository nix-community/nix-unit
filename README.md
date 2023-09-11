# nix-unit

This project runs an attribute set of tests compatible with `lib.debug.runTests` while allowing individual attributes to fail.

![](./.github/demo.gif)


## Why use nix-unit?

- Simple structure compatible with `lib.debug.runTests`

- Allows individual test attributes to fail individually.

Rather than evaluating the entire test suite in one go, serialise & compare `nix-unit` uses the Nix evaluator C++ API.
Meaning that we can catch test failures individually, even if the failure is caused by an evaluation error.

- Fast.

No additional processing and coordination overhead caused by the external process approach.

## Examples

## Simple (classic)
In it's simplest form a `nix-unit` test suite is just an attribute set where test attributes are prefix with `test`.
Test attribute sets contain the keys `expr`, expressing the test & `expected`, expressing the expected results.

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

Evaluated with `nix-unit`:
`$ nix-unit test.nix`


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

## Simple (flakes)

Building on top of the simple classic example the same type of structure could also be expressed in a `flake.nix`:
``` nix
{
  description = "A very basic flake using nix-unit";

  outputs = { self, nixpkgs }: {
    libTests = {
      testPass = {
        expr = 1;
        expected = 1;
      };
    };
  };
}

```

And is evaluated with `nix-unit` like so:
`$ nix-unit --flake .#libTests`

## Test trees
While simple flat attribute sets works you might want to express your tests as a deep attribute set.
When `nix-unit` encounters an attribute which name is _not_ prefixed with `test` it recurses into that attribute to find more tests.

Example:
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

  nested = {
    testFoo = {
      expr = "bar";
      expected = "bar";
    };
  };
}
```

## Test errors

While testing the happy path is a good start, you might also want to verify that expressions throw the error you expect. You check for a specifc type of error by setting `expectedError.type` and/or use `expectedError.msg` to search its message for the given regex.

Example:

`tests/default.nix`
``` nix
{
  testCatchMessage = {
    expr = throw "10 instead of 5";
    expectedError.type = "ThrownError";
    expectedError.msg = "\\d+ instead of 5";
  };
}
```
->
```
✅ testCatchMessage

🎉 1/1 successful
```


> Note: Regular expression like the one above are supported

### Supported error types

The following values for `expectedError.type` are valid:

* `RestrictedPathError`
* `MissingArgumentError`
* `UndefinedVarError`
* `TypeError`
* `Abort`
* `ThrownError`
* `AssertionError`
* `ParseError`
* `EvalError`

## FAQ

### What about a watch mode?
This adds a lot of additional complexity and for now is better dealt with by using external file watcher tools such as [Reflex](https://github.com/cespare/reflex) & [Watchman](https://facebook.github.io/watchman/).

### Can I change the colors?

`nix-unit` uses [difftastic](github.com/wilfred/difftastic), which can be configured via environment variables. You can turn off
colors via `DFT_COLOR=never`, give difftastic a hint for choosing better colors with `DFT_BACKGROUND=light` or see the full
list of options via e.g. `nix run nixpkgs#difftastic -- --help`.

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
