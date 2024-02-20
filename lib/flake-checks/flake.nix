{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      tests.testPass = { expr = 3; expected = 4; };

      checks.default = pkgs.stdenv.mkDerivation {
        name = "default";
        phases = [ "unpackPhase" "buildPhase" ];
        src = inputs.self;
        nativeBuildInputs = [ inputs.nix-unit.packages.${system}.default ];
        buildPhase = ''
          export HOME="$(realpath .)"
          nix-unit \
            --eval-store "$HOME" \
            --flake \
            --option extra-experimental-features flakes \
            --override-input nixpkgs ${inputs.nixpkgs.outPath} \
            --override-input flake-utils ${inputs.flake-utils.outPath} \
            --override-input flake-utils/systems ${inputs.flake-utils.inputs.systems.outPath} \
            .#tests.${system}
          touch $out
        '';
      };
    }
  );
}
