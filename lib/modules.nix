/**
  [flake-parts] modules exported by the nix-unit flake.

  The nix-unit flake itself does not depend on flake-parts; these modules are
  evaluated in the consumer's flake-parts instance.

  flake-parts: https://flake.parts
*/
{ self }:
{
  /**
    Provide only the `flake.tests` option, with rudimentary merging.

    Does not provide `nix flake check` support.
  */
  testsOutput = ./modules/flake/tests-output.nix;

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
              default = self.packages.${system}.nix-unit;
              defaultText = lib.literalMD ''
                package from the `nix-unit` flake, using that flake's `inputs.nixpkgs` (except for `follows`, etc)
              '';
            };
          };
        }
      );
    };
}
