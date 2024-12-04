/**
  This module defines the `modules` flake output.
*/

# nix-unit flake context
{ withSystem, ... }:
{
  /**
    [flake-parts] modules.

    flake-parts: https://flake.parts
  */
  flake.modules.flake = {
    /**
      Provide only the `flake.tests` option, with rudimentary merging.

      Does not provide `nix flake check` support.
    */
    testsOutput = ./modules/flakes/tests-output.nix;

    /**
      Provides all functionality, including `nix flake check` support and system-specific tests.
    */
    default =
      # user flake context
      { lib, flake-parts-lib, ... }:
      {
        imports = [
          ./modules/flake/system.nix
          ./modules/flake/system-agnostic.nix
        ];
        options.perSystem = flake-parts-lib.mkPerSystemOption (
          # user flake perSystem
          { system, ... }:
          {
            options.nix-unit = {
              package = lib.mkOption {
                default = withSystem system ({ config, ... }: config.packages.nix-unit);
                defaultText = lib.literalMD ''
                  package from the `nix-unit` flake, using that flake's `inputs.nixpkgs` (except for `follows`, etc)
                '';
              };
            };
          }
        );
      };
  };
}
