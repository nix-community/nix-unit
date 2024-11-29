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
  nix,
  nlohmann_json,
  pkg-config,
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
  version = "2.24.1";
  inherit src;
  buildInputs = [
    nlohmann_json
    nix
    boost
  ];
  nativeBuildInputs = [
    makeWrapper
    meson
    pkg-config
    ninja
    # nlohmann_json can be only discovered via cmake files
    cmake
  ] ++ (lib.optional stdenv.cc.isClang [ clang-tools ]);

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
