{
  lib,
  stdenv,
  mkShell,
  python3,
  difftastic,
  nixdoc,
  mdbook,
  mdbook-open-on-gh,
  mdbook-cmdrun,
  curl,
  nix-unit,
  treefmt,
  self,
}:
let
  pythonEnv = python3.withPackages (_ps: [ ]);
in
mkShell {
  nativeBuildInputs = nix-unit.nativeBuildInputs ++ [
    pythonEnv
    difftastic
    nixdoc
    mdbook
    mdbook-open-on-gh
    mdbook-cmdrun
    treefmt
  ];
  inherit (nix-unit) buildInputs;
  shellHook = lib.optionalString stdenv.isLinux ''
    export NIX_DEBUG_INFO_DIRS="${curl.debug}/lib/debug''${NIX_DEBUG_INFO_DIRS:+:$NIX_DEBUG_INFO_DIRS}"
    export NIX_UNIT_OUTPATH=${self}
  '';
}
