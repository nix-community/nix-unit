{
  stdenv,
  nixdoc,
  self ? ../.,
  mdbook,
  mdbook-cmdrun,
  mdbook-open-on-gh,
  git,
}:

stdenv.mkDerivation {
  pname = "nix-unit-docs-html";
  version = "0.1";
  src = self;
  nativeBuildInputs = [
    nixdoc
    mdbook
    mdbook-open-on-gh
    mdbook-cmdrun
    git
  ];

  dontConfigure = true;
  dontFixup = true;

  env.RUST_BACKTRACE = 1;

  buildPhase = ''
    runHook preBuild
    cd doc
    chmod +w ../ && mkdir ../.git  # Trick open-on-gh to find the git root
    mdbook build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mv book $out
    runHook postInstall
  '';
}
