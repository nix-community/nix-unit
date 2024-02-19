# Simple

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
``` bash
$ nix-unit test.nix
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
