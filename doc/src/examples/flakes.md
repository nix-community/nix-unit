# Flakes

## flake.nix

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
``` bash
$ nix-unit --flake '.#libTests'
```

## flake checks

You can also use `nix-unit` in flake checks ([link](https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake-check)).

Create a `tests` and `checks` outputs.

```nix
{{#include ../lib/flake-checks/flake.nix}}
```

Run `nix flake check` and get an error as expected.

```console
error: builder for '/nix/store/73d58ybnyjql9ddy6lr7fprxijbgb78n-nix-unit-tests.drv' failed with exit code 1;
       last 10 log lines:
       > /build/nix-20-1/expected.nix --- 1/2 --- Nix
       > 1 3
       >
       > /build/nix-20-1/expected.nix --- 2/2 --- Nix
       > 1 4
       >
       >
       >
       > 😢 0/1 successful
       > error: Tests failed
       For full logs, run 'nix log /nix/store/73d58ybnyjql9ddy6lr7fprxijbgb78n-nix-unit-tests.drv'.
```
