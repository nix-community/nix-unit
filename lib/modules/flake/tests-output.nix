{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit ((import ../types.nix { inherit lib; }).types) suite;
in
{
  options = {
    flake.tests = mkOption {
      type = suite;
      default = { };
      description = ''
        A nix-unit test suite; as [introduced in the manual](https://nix-community.github.io/nix-unit/examples/simple.html).
      '';
      example = lib.literalExpression ''
        {
          "test integer equality is reflexive" = {
            expr = "123";
            expected = "123";
          };
          "frobnicator" = {
            "testFoo" = {
              expr = "foo";
              expected = "foo";
            };
          }
        }
      '';
    };
  };
}
