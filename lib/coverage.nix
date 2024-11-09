{ lib }:
let
  inherit (lib) toUpper substring stringLength;

  capitalise = s: toUpper (substring 0 1 s) + (substring 1 (stringLength s) s);

in
{

  /*
    Generate coverage testing for public interfaces.

    Example:

    # Expression
    let
      # The public interface (attrset) we are testing
      public = {
        addOne = x: x + 1;
      };
      # Test suite
      tests = {
        addOne = {
          testAdd = {
            expr = public.addOne 1;
            expected = 2;
          };
        };
      };
    in addCoverage public tests

    # Returns
    {
      addOne = {
        testAdd = {
          expected = 2;
          expr = 2;
        };
      };
      coverage = {
        testAddOne = {
          expected = true;
          expr = true;
        };
      };
    }
  */
  addCoverage =
    # The public interface to generate coverage for
    public:
    # Attribute set of tests to match agains
    tests:
    (
      assert !tests ? coverage;
      tests
      // {
        coverage = lib.mapAttrs' (n: _v: {
          name = "test" + (capitalise n);
          value = {
            expr = tests ? ${n};
            expected = true;
          };
        }) public;
      }
    );

}
