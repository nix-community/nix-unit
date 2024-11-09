{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = _: {
    testSuites = {
      basic = import ./basic.nix;
    };
  };
}
