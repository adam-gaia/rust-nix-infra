{
  flake,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs.rust-nix-infra.lib) mkWorkspace;
  inherit (flake.lib) commonArgs;
  workspace = mkWorkspace pkgs commonArgs;
  inherit (workspace) cargo-nextest;
in

cargo-nextest
