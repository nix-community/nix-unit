# Flakes

Building on top of the simple classic example the same type of structure could also be expressed in a `flake.nix`:
``` nix
{
  description = "A very basic flake using nix-unit";

  outputs = { self, nixpkgs }: {
    libTests = {
      testPass = {
        expr = 1;
        expected = 1;
      };
    };
  };
}

```

And is evaluated with `nix-unit` like so:
``` bash
$ nix-unit --flake '.#libTests'
```
