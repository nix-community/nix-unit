{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-unit.modules.flake.default
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { ... }:
        {
          nix-unit.inputs = {
            # NOTE: a `nixpkgs-lib` follows rule is currently required
            inherit (inputs) nixpkgs flake-parts nix-unit;
          };
          # Tests specified here may refer to system-specific attributes that are
          # available in the `perSystem` context
          nix-unit.tests = {
            "test integer equality is reflexive" = {
              expr = "123";
              expected = "123";
            };
            "frobnicator" = {
              "testFoo" = {
                expr = "foo";
                expected = "foo";
              };
            };
          };
        };
      flake = {
        # System-agnostic tests can be defined here, and will be picked up by
        # `nix flake check`
        tests.testBar = {
          expr = "bar";
          expected = "bar";
        };
      };
    };
}
