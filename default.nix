{ stdenv
, lib
, nix
, pkgs
, srcDir ? null
, makeWrapper
, difftastic
}:

let
  filterMesonBuild = builtins.filterSource
    (path: type: type != "directory" || baseNameOf path != "build");
in
stdenv.mkDerivation {
  pname = "nix-unit";
  version = "0.1";
  src = if srcDir == null then filterMesonBuild ./. else srcDir;
  buildInputs = with pkgs; [
    nlohmann_json
    nix
    boost
  ];
  nativeBuildInputs = with pkgs; [
    makeWrapper
    bear
    meson
    pkg-config
    ninja
    # nlohmann_json can be only discovered via cmake files
    cmake
  ] ++ (lib.optional stdenv.cc.isClang [ pkgs.bear pkgs.clang-tools ]);

  postInstall = ''
    wrapProgram "$out/bin/nix-unit" --prefix PATH : ${lib.getExe difftastic}
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
