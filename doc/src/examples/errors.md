# Testing errors

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
