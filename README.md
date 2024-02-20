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

## Comparison with other tools
This comparison matrix was originally taken from [Unit test your Nix code](https://www.tweag.io/blog/2022-09-01-unit-test-your-nix-code/) but has been adapted.
Pythonix is excluded as it's unmaintained.

| Tool        | Can test eval failures | Tests defined in Nix | in nixpkgs | snapshot testing(1) |
| ----------- | ---------------------- | -------------------- | ---------- |-------------------- |
| Nix-unit    | yes                    | yes                  | yes        | no                  |
| runTests    | no                     | yes                  | yes        | no                  |
| Nixt        | no                     | yes                  | no         | no                  |
| Namaka      | no                     | yes                  | yes        | yes                 |

1. [Snapshot testing](https://github.com/nix-community/namaka#snapshot-testing)

## Documentation

https://nix-community.github.io/nix-unit/
