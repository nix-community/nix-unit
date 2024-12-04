{ lib }:

/**
  Module system types for nix-unit.
*/
{
  /**
    A nix-unit test suite as [introduced in the manual](https://nix-community.github.io/nix-unit/examples/simple.html).

    A more advanced type could be provided, but this would require
      - optional fields
          - e.g. https://github.com/NixOS/nixpkgs/pull/334680
      - name-dependent attribute value types.
          - e.g. `itemTypeFunction` behavior in https://github.com/NixOS/nixpkgs/pull/344216#issuecomment-2373878236

    The value of type-checking is dubious, and we don't know how well the
    documentation tooling would render this complicated type.
  */
  # This type could be refined, to allow more sophisticated merging, but for
  # now, merging only the top-level keys seems sufficient.
  types.suite = lib.types.lazyAttrsOf lib.types.raw;
}
