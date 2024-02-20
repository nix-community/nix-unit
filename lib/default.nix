{ lib }:
{
  coverage = import ./coverage.nix { inherit lib; };
}
