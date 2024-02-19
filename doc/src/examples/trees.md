# Trees

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

Results in the output:
``` bash
✅ nested.testFoo
❌ testFail
/run/user/1000/nix-244499-0/expected.nix --- Nix
1 { x = 1; }                                         1 { y = 1; }


☢️ testFailEval
error:
       … while calling the 'throw' builtin

         at /home/adisbladis/sauce/github.com/nix-community/nix-unit/trees.nix:13:12:

           12|   testFailEval = {
           13|     expr = throw "NO U";
             |            ^
           14|     expected = 0;

       error: NO U

✅ testPass

😢 2/4 successful
error: Tests failed
```
