/**
  This module defines system-specific nix-unit integration logic, such as the
  `perSystem.nix-unit` options and the `checks`.
*/

{
  config,
  lib,
  flake-parts-lib,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit ((import ../types.nix { inherit lib; }).types) suite;
  overrideArg =
    name: value: "--override-input ${lib.escapeShellArg name} ${lib.escapeShellArg "${value}"}";
in
{
  imports = [ ./tests-output.nix ];
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      system,
      ...
    }:

    let
      # Turn a derivation that writes `key` to `$out` into a check that's unique to the derivation.
      toNetworkedCheck =
        drv:
        let
          # key as in functional key
          key =
            # Discarding string context is safe, because we're not trying to read any store path contents.
            "check derived from ${baseNameOf (builtins.unsafeDiscardStringContext drv.drvPath)} is ok\n";
        in
        drv.overrideAttrs (old: {
          # To be written to $out by the builder
          inherit key;
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.cacert ];
          outputHashAlgo = "sha256";
          outputHashMode = "flat";
          outputHash = builtins.hashString "sha256" key;
        });
    in
    {
      options.nix-unit = {
        package = mkOption {
          type = types.package;
          description = ''
            The nix-unit package to use.
          '';
        };
        inputs = mkOption {
          type = types.attrsOf types.path;
          default = { };
          description = ''
            Input overrides to pass to nix-unit.

            Since nix-unit will be invoked in the nix sandbox, any flake inputs
            that are required for the tests must be passed here.

            This prevents the need to download these inputs for each run.
          '';
          example = lib.literalExpression ''
            {
              inherit (inputs) nixpkgs flake-parts;
            }
          '';
        };
        allowNetwork = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to allow network access in the nix-unit tests.
            This is useful for tests that depend on fetched sources, as is often the case with flake inputs.
            `nix-unit.inputs` may also be a solution, and tends to perform better.
            Both solutions can be combined.
          '';
        };
        tests = mkOption {
          type = suite;
          default = { };
          description = ''
            A nix-unit test suite; as [introduced in the manual](https://nix-community.github.io/nix-unit/examples/simple.html).
          '';
          example = lib.literalExpression ''
            {
              "test integer equality is reflexive" = {
                expr = "123";
                expected = "123";
              };
              "frobnicator" = {
                "testFoo" = {
                  expr = "foo";
                  expected = "foo";
                };
              }
            }
          '';
        };
      };
      config = {
        checks.nix-unit = (if config.nix-unit.allowNetwork then toNetworkedCheck else x: x) (
          pkgs.runCommandNoCC "nix-unit-check"
            {
              nativeBuildInputs = [ config.nix-unit.package ];
              # For toNetworkedCheck to override
              key = "";
            }
            ''
              unset NIX_BUILD_TOP
              export HOME="$(realpath .)"
              echo "Running tests for " ${lib.escapeShellArg system}
              nix-unit --eval-store "$HOME" \
                --show-trace \
                --extra-experimental-features flakes \
                ${lib.concatStringsSep "\\\n  " (lib.mapAttrsToList overrideArg config.nix-unit.inputs)} \
                --flake ${self}#tests.systems.${system} \
                ;
              env | grep NIX_
              echo "Writing $key to $out"
              echo -n "$key" > $out
            ''
        );
      };
    }
  );
  config = {
    flake = {
      tests.systems = lib.mapAttrs (_system: config: config.nix-unit.tests) config.allSystems;
    };
  };
}
