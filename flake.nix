{
  description = "Nix unit test runner";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.flake-parts.flakeModules.partitions
        ./lib/modules.nix
        ./templates/flake-module.nix
      ];

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
        in
        {
          packages.nix-unit = pkgs.callPackage ./default.nix {
            nixComponents = pkgs.nixVersions.nixComponents_2_30;
          };
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
                # TODO: add Nix debug symbols
                export NIX_DEBUG_INFO_DIRS="${pkgs.curl.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
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
