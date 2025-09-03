{
  flake,
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (inputs.rust-nix-infra.lib) mkWorkspace;
  inherit (flake.lib) commonArgs;
  workspace = mkWorkspace pkgs commonArgs;
  inherit (workspace) llvm-coverage;
in
llvm-coverage
