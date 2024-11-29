/**
  This module is loaded into the nix-unit flake sets up some example tests, to
  test the nix-unit flake modules.
*/

{ inputs, ... }:
{
  perSystem = {
    nix-unit.inputs = {
      inherit (inputs) nixpkgs flake-parts treefmt-nix;
    };
    nix-unit.tests = {
      "test integer equality is reflexive" = {
        expr = "123";
        expected = "123";
      };
      "frobnicator" = {
        "testFoo" = {
          expr = "foo";
          expected = "foo";
        };
      };
    };
  };
  flake.tests.testBar = {
    expr = "bar";
    expected = "bar";
  };
}
