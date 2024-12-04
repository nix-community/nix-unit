{ self, inputs, ... }:
{
  flake.templates.flake-parts = {
    description = "Example flake with nix-unit and flake-parts";
    path = "${./flake-parts}";
  };
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      checks =
        let
          # More robust, slower alternative:
          # cache = "file://${pkgs.mkBinaryCache {
          #   rootPaths = [ config.checks.nix-unit.inputDerivation ];
          # }}";
          cache = "file://${
            pkgs.mkBinaryCache {
              rootPaths = [
                (pkgs.runCommandNoCC "dummy" {
                  nativeBuildInputs = [ config.packages.nix-unit ];
                } "").inputDerivation
              ];
            }
          }";

          template-flake-parts =
            pkgs.runCommandNoCC "template-flake-parts"
              {
                nativeBuildInputs = [ pkgs.nix ];

                # might be fixed in https://github.com/NixOS/nix/pull/11910
                thisReallyShouldntBeNecessary = "${./flake-parts}";

                NIX_CONFIG = ''
                  experimental-features = nix-command flakes
                  substituters = ${builtins.storeDir} ${cache}
                  show-trace = true
                '';
                meta.maintainers = with pkgs.lib.maintainers; [ roberth ];
              }
              ''
                mkdir -p home/.config/nix myflake nix-unit
                export HOME=$PWD/home
                ( 
                  cd $HOME;
                  echo "store = $HOME/.local/share/nix/root" > .config/nix/nix.conf
                )
                (
                  cd nix-unit
                  cat > flake.nix <<EOF
                {
                  description = "A flake for the purpose of replicating nix-unit offline";
                  inputs = {
                    nixpkgs.url = "${inputs.nixpkgs}";
                    flake-parts.url = "${inputs.flake-parts}";
                    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
                    nix-unit.url = "${self}";
                    nix-unit.inputs.flake-parts.follows = "flake-parts";
                  };
                  outputs = inputs: inputs.nix-unit;
                }
                EOF
                )

                cd myflake
                (
                  overrides=(
                    --override-input flake-parts ${inputs.flake-parts}
                    --override-input nixpkgs ${inputs.nixpkgs}
                    --override-input nix-unit ${self}
                  )
                  set -x
                  # prime the store
                  # nix eval ../nix-unit#templates.flake-parts.path --offline
                  nix copy --from ${cache} --all --no-check-sigs
                  nix flake init -t ../nix-unit#flake-parts --offline
                  nix flake check -vL "''${overrides[@]}"
                )

                touch $out
              '';
        in
        lib.optionalAttrs
          # error: building using a diverted store is not supported on this platform
          (!pkgs.buildPlatform.isDarwin)
          {
            inherit template-flake-parts;
          };
    };
}
