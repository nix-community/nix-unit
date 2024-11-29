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
          '';
          example = lib.literalExpression ''
            {
              inherit (inputs) nixpkgs flake-parts;
            }
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
        checks.nix-unit =
          pkgs.runCommandNoCC "nix-unit-check"
            {
              nativeBuildInputs = [ config.nix-unit.package ];
            }
            ''
              export HOME="$(realpath .)"
              echo "Running tests for " ${lib.escapeShellArg system}
              nix-unit --eval-store "$HOME" \
                --show-trace \
                --extra-experimental-features flakes \
                ${lib.concatStringsSep "\\\n  " (lib.mapAttrsToList overrideArg config.nix-unit.inputs)} \
                --flake ${self}#tests.systems.${system} \
                ;
              touch $out
            '';
      };
    }
  );
  config = {
    flake = {
      tests.systems = lib.mapAttrs (_system: config: config.nix-unit.tests) config.allSystems;
    };
  };
}
