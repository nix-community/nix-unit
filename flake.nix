{
  description = "Nix unit test runner";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nix-github-actions.url = "github:nix-community/nix-github-actions";
  inputs.nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nix.url = "github:NixOS/nix/master";

  outputs = inputs @ { flake-parts, nix-github-actions, ... }:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
    in
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        systems = inputs.nixpkgs.lib.systems.flakeExposed;
        imports = [ inputs.treefmt-nix.flakeModule ];

        flake.githubActions = nix-github-actions.lib.mkGithubMatrix {
          checks = {
            x86_64-linux = builtins.removeAttrs (self.packages.x86_64-linux // self.checks.x86_64-linux) [ "default" ];
            x86_64-darwin = builtins.removeAttrs (self.packages.x86_64-darwin // self.checks.x86_64-darwin) [ "default" "treefmt" ];
          };
        };

        perSystem = { pkgs, self', inputs', ... }:
          let
            inherit (pkgs) stdenv;
            drvArgs = {
              srcDir = self;
              nix = inputs'.nix.packages.nix;
            };
          in
          {
            treefmt.imports = [ ./dev/treefmt.nix ];
            packages.nix-unit = pkgs.callPackage ./default.nix drvArgs;
            packages.default = self'.packages.nix-unit;
            devShells.default =
              let
                pythonEnv = pkgs.python3.withPackages (_ps: [ ]);
              in
              pkgs.mkShell {
                nativeBuildInputs = self'.packages.nix-unit.nativeBuildInputs ++ [
                  pythonEnv
                  pkgs.difftastic
                ];
                inherit (self'.packages.nix-unit) buildInputs;
                shellHook = lib.optionalString stdenv.isLinux ''
                  export NIX_DEBUG_INFO_DIRS="${pkgs.curl.debug}/lib/debug:${drvArgs.nix.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
                '';
              };
          };
      };
}
