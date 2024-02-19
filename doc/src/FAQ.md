# FAQ

## What about a watch mode?
This adds a lot of additional complexity and for now is better dealt with by using external file watcher tools such as [Reflex](https://github.com/cespare/reflex) & [Watchman](https://facebook.github.io/watchman/).

## Can I change the colors?

`nix-unit` uses [difftastic](https://github.com/wilfred/difftastic), which can be configured via environment variables. You can turn off
colors via `DFT_COLOR=never`, give difftastic a hint for choosing better colors with `DFT_BACKGROUND=light` or see the full
list of options via e.g. `nix run nixpkgs#difftastic -- --help`.

## Comparison with other tools
This comparison matrix was originally taken from [Unit test your Nix code](https://www.tweag.io/blog/2022-09-01-unit-test-your-nix-code/) but has been adapted.
Pythonix is excluded as it's unmaintained.

| Tool        | Can test eval failures | Tests defined in Nix | in nixpkgs | snapshot testing(1) |
| ----------- | ---------------------- | -------------------- | ---------- |-------------------- |
| Nix-unit    | yes                    | yes                  | yes        | no                  |
| runTests    | no                     | yes                  | yes        | no                  |
| Nixt        | no                     | yes                  | no         | no                  |
| Namaka      | no                     | yes                  | yes        | yes                 |

1. [Snapshot testing](https://github.com/nix-community/namaka#snapshot-testing)
