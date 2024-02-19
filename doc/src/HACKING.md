# Hacking

This document outlines hacking on `nix-unit` itself.

## Getting started

To start hacking run either `nix-shell` (stable Nix) `nix develop` (Nix Flakes).

Then create the meson build directory:
``` sh
$ meson build
$ cd build
```

And use `ninja` to build:
``` sh
$ ninja
```
## Formatter

Before submitting a PR format the code with `nix fmt` and ensure Flake checks pass with `nix flake check`.
