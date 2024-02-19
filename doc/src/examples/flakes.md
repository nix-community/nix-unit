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
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      tests.testPass = { expr = 3; expected = 4; };

      checks.default = pkgs.stdenv.mkDerivation {
        name = "default";
        phases = [ "unpackPhase" "buildPhase" ];
        src = inputs.self;
        buildPhase = ''
          ${pkgs.lib.getExe pkgs.nix-unit} \
            --eval-store $(realpath .) \
            --flake \
            --option extra-experimental-features flakes \
            --override-input nixpkgs ${inputs.nixpkgs.outPath} \
            --override-input flake-utils ${inputs.flake-utils.outPath} \
            --override-input flake-utils/systems ${inputs.flake-utils.inputs.systems.outPath} \
            .#tests.${system}
          touch $out
        '';
      };
    }
  );
}
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
