{
  # Used to find the project root
  projectRootFile = "flake.lock";

  programs.clang-format.enable = true;
  programs.deadnix.enable = true;
  programs.nixfmt.enable = true;
  programs.ruff.format = true;
  programs.ruff.check = true;
}
