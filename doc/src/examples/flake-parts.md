# Flake-parts

`nix-unit` provides a [flake-parts](https://flake.parts) module for easy integration with flakes.

You can write tests in the option [`flake.tests`] and/or [`perSystem.nix-unit.tests`].

The module then takes care of setting up a [`checks`] derivation for you.

For this to work, you may have to specify [`perSystem.nix-unit.inputs`] to make them available in the derivation.
This tends to require that you flatten some of your [`inputs`] tree using `follows`.

## Example

This example can be used with `nix flake init -t github:nix-community/nix-unit#flake-parts`.

```nix
<!-- cmdrun cat ../../../templates/flake-parts/flake.nix -->
```

[`perSystem.nix-unit.inputs`]: https://flake.parts/options/nix-unit#opt-perSystem.nix-unit.inputs
[`perSystem.nix-unit.tests`]: https://flake.parts/options/nix-unit#opt-perSystem.nix-unit.tests
[`flake.tests`]: https://flake.parts/options/nix-unit#opt-flake.tests
[`checks`]: https://flake.parts/options/flake-parts#opt-perSystem.checks
[`inputs`]: https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake.html#flake-inputs
