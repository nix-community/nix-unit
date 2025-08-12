{
  stdenv,
  lib,
  boost,
  clang-tools,
  cmake,
  difftastic,
  makeWrapper,
  meson,
  ninja,
  nlohmann_json,
  pkg-config,
  nixComponents,
}:

let
  inherit (lib) fileset;
  src = lib.fileset.toSource {
    fileset = files;
    root = ./.;
  };
  files = fileset.unions [
    ./src
    ./meson.build
  ];
in
stdenv.mkDerivation {
  pname = "nix-unit";
  version = "2.30.0";
  inherit src;
  buildInputs = [
    nlohmann_json
    nixComponents.nix-main
    nixComponents.nix-store
    nixComponents.nix-expr
    nixComponents.nix-cmd
    nixComponents.nix-flake
    boost
  ];
  nativeBuildInputs = [
    makeWrapper
    meson
    pkg-config
    ninja
    # nlohmann_json can be only discovered via cmake files
    cmake
  ]
  ++ (lib.optional stdenv.cc.isClang [ clang-tools ]);

  postInstall = ''
    wrapProgram "$out/bin/nix-unit" --prefix PATH : ${difftastic}/bin
  '';

  meta = {
    description = "Nix unit test runner";
    homepage = "https://github.com/adisbladis/nix-unit";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ adisbladis ];
    platforms = lib.platforms.unix;
    mainProgram = "nix-unit";
  };
}
