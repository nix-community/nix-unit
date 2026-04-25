{
  description = "Nix unit test runner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      nix-github-actions,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      treefmtFor = forAllSystems (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./dev/treefmt.nix
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          nix-unit = pkgs.callPackage ./default.nix {
            nixComponents = pkgs.nixVersions.nixComponents_2_31;
          };
          default = self.packages.${system}.nix-unit;
          doc = pkgs.callPackage ./doc { inherit self; };
        }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./dev/shell.nix {
          inherit self;
          inherit (self.packages.${system}) nix-unit;
          treefmt = treefmtFor.${system}.config.build.wrapper;
        };
      });

      checks = forAllSystems (system: {
        treefmt = treefmtFor.${system}.config.build.check self;
      });

      formatter = forAllSystems (system: treefmtFor.${system}.config.build.wrapper);

      templates.flake-parts = {
        description = "Example flake with nix-unit and flake-parts";
        path = ./templates/flake-parts;
      };

      # flake-parts module for consumers; this flake itself does not depend on
      # flake-parts so that downstream lock files stay small.
      modules.flake = import ./lib/modules.nix { inherit self; };

      lib = import ./lib { inherit lib; };

      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = {
          x86_64-linux = builtins.removeAttrs (self.packages.x86_64-linux // self.checks.x86_64-linux) [
            "default"
          ];
          aarch64-darwin = builtins.removeAttrs (self.packages.aarch64-darwin // self.checks.aarch64-darwin) [
            "default"
            "treefmt"
          ];
        };
      };
    };
}
