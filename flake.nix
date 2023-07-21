{
  description = "Nix unit test runner";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs @ { flake-parts, ... }:
    let
      inherit (inputs.nixpkgs) lib;
      inherit (inputs) self;
    in
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        systems = inputs.nixpkgs.lib.systems.flakeExposed;
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem = { pkgs, self', system, ... }:
          let
            inherit (pkgs) stdenv;
            drvArgs = {
              srcDir = self;
              nix = pkgs.nixUnstable;
            };
          in
          {
            treefmt.imports = [ ./dev/treefmt.nix ];
            packages.nix-unit = pkgs.callPackage ./default.nix drvArgs;
            packages.default = self'.packages.nix-unit;
            devShells.default = pkgs.mkShell {
              inherit (self.packages.${system}.nix-unit) nativeBuildInputs buildInputs;
              shellHook = lib.optionalString stdenv.isLinux ''
                export NIX_DEBUG_INFO_DIRS="${pkgs.curl.debug}/lib/debug:${drvArgs.nix.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
              '';
            };
          };
      };
}
