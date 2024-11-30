{
  description = "Nix unit test runner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, nix-github-actions, ... }:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.flake-parts.flakeModules.partitions
        ./lib/modules.nix
        ./templates/flake-module.nix
      ];

      flake.githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = {
          x86_64-linux = builtins.removeAttrs (self.packages.x86_64-linux // self.checks.x86_64-linux) [
            "default"
          ];
          x86_64-darwin = builtins.removeAttrs (self.packages.x86_64-darwin // self.checks.x86_64-darwin) [
            "default"
            "treefmt"
          ];
        };
      };

      flake.lib = import ./lib { inherit lib; };

      perSystem =
        {
          config,
          pkgs,
          self',
          ...
        }:
        let
          inherit (pkgs) stdenv;
          drvArgs = {
            srcDir = self;
            nix = pkgs.nixVersions.nix_2_24;
          };
        in
        {
          packages.nix-unit = pkgs.callPackage ./default.nix drvArgs;
          packages.default = self'.packages.nix-unit;
          packages.doc = pkgs.callPackage ./doc {
            inherit self;
          };
          devShells.default =
            let
              pythonEnv = pkgs.python3.withPackages (_ps: [ ]);
            in
            pkgs.mkShell {
              nativeBuildInputs = self'.packages.nix-unit.nativeBuildInputs ++ [
                pythonEnv
                pkgs.difftastic
                pkgs.nixdoc
                pkgs.mdbook
                pkgs.mdbook-open-on-gh
                pkgs.mdbook-cmdrun
                config.treefmt.build.wrapper
              ];
              inherit (self'.packages.nix-unit) buildInputs;
              shellHook = lib.optionalString stdenv.isLinux ''
                export NIX_DEBUG_INFO_DIRS="${pkgs.curl.debug}/lib/debug:${drvArgs.nix.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
                export NIX_UNIT_OUTPATH=${self}
              '';
            };
        };

      # Extra things to load only when accessing development-specific attributes
      # such as `checks`
      partitionedAttrs.checks = "dev";
      partitionedAttrs.devShells = "dev";
      partitionedAttrs.tests = "dev"; # lib/modules/flake/dogfood.nix
      partitions.dev.module = {
        imports = [
          inputs.treefmt-nix.flakeModule
          self.modules.flake.default
          ./lib/modules/flake/dogfood.nix
        ];
        perSystem = {
          treefmt.imports = [ ./dev/treefmt.nix ];
        };
      };
    };
}
