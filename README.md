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

| Tool        | Can test eval failures | Tests defined in Nix | in nixpkgs | snapshot testing(1) | Supports Lix |
| ----------- | ---------------------- | -------------------- | ---------- |-------------------- | ------------ |
| Nix-unit    | yes                    | yes                  | yes        | no                  | no           |
| Lix-unit    | yes                    | yes                  | no         | no                  | yes (2)      |
| runTests    | no                     | yes                  | yes        | no                  | yes          |
| Nixt        | no                     | yes                  | no         | no                  | yes          |
| Namaka      | no                     | yes                  | yes        | yes                 | ?            |

1. [Snapshot testing](https://github.com/nix-community/namaka#snapshot-testing)
2. While lix-unit supports Lix, it does not support Nix, and vice versa.

## Using with Lix instead of Nix

The Lix codebase has gone through significant changes, and it's not tenable to have a single code base that supports both implementations.
Therefore nix-unit has been forked into [lix-unit](https://github.com/adisbladis/lix-unit)

## Documentation

https://nix-community.github.io/nix-unit/
