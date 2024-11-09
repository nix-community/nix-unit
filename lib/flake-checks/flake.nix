{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      nixpkgs,
      nix-unit,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-windows"
      ];
    in
    {
      tests.testPass = {
        expr = 3;
        expected = 4;
      };

      checks = forAllSystems (system: {
        default =
          nixpkgs.legacyPackages.${system}.runCommand "tests"
            {
              nativeBuildInputs = [ nix-unit.packages.${system}.default ];
            }
            ''
              export HOME="$(realpath .)"
              # The nix derivation must be able to find all used inputs in the nix-store because it cannot download it during buildTime.
              nix-unit --eval-store "$HOME" \
                --extra-experimental-features flakes \
                --override-input nixpkgs ${nixpkgs} \
                --flake ${self}#tests
              touch $out
            '';
      });
    };
}
