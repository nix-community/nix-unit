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
      nix-github-actions,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      inherit (nixpkgs) lib;

    in
    {

      githubActions = nix-github-actions.lib.mkGithubMatrix {
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

      lib = import ./lib { inherit lib; };

      templates = {
        flake-parts = {
          description = "Example flake with nix-unit and flake-parts";
          path = ./templates/flake-parts;
        };
      };

      # TODO: Figure out how to distribute flake-parts without using flake-parts on the top-level
      modules = throw "Dunno lol";

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          drvArgs = {
            nix = pkgs.nixVersions.nix_2_24;
          };
        in
        {
          nix-unit = pkgs.callPackage ./default.nix drvArgs;
          default = self.packages.${system}.nix-unit;
          doc = pkgs.callPackage ./doc {
            inherit self;
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        (treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix).config.build.wrapper
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) stdenv;
          drvArgs = {
            nix = pkgs.nixVersions.nix_2_24;
          };
        in
        {
          default =
            let
              pythonEnv = pkgs.python3.withPackages (_ps: [ ]);
            in
            pkgs.mkShell {
              nativeBuildInputs = self.packages.${system}.nix-unit.nativeBuildInputs ++ [
                pythonEnv
                pkgs.difftastic
                pkgs.nixdoc
                pkgs.mdbook
                pkgs.mdbook-open-on-gh
                pkgs.mdbook-cmdrun
                self.formatter.${system}
              ];
              inherit (self.packages.${system}.nix-unit) buildInputs;
              shellHook = lib.optionalString stdenv.isLinux ''
                export NIX_DEBUG_INFO_DIRS="${pkgs.curl.debug}/lib/debug:${drvArgs.nix.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
                export NIX_UNIT_OUTPATH=${self}
              '';
            };
        }
      );

    };
}
