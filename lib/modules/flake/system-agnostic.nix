/**
  This module is responsible for testing the system-agnostic tests that may be
  defined in the flake's `tests` attribute (besides the `systems` attribute).
*/

top@{ flake-parts-lib, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
in
{
  imports = [ ./tests-output.nix ];
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.nix-unit = {
        enableSystemAgnostic = mkOption {
          default = true;
          type = types.bool;
          description = ''
            Copy system-agnostic tests from the `flake.tests` attribute into this system's tests.

            This ensures that the tests that are not defined in the system-specific tests are still run in `nix flake check`.
          '';
        };
      };
      config = mkIf config.nix-unit.enableSystemAgnostic {
        nix-unit.tests.system-agnostic = lib.removeAttrs top.config.flake.tests [ "systems" ];
      };
    }
  );
}
