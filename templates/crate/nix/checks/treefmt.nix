{
  flake,
  inputs,
  pkgs,
  ...
}:
let

  inherit (inputs.rust-nix-infra) mkTreefmt;
  treefmt = mkTreefmt pkgs flake ../treefmt.nix;
  inherit (treefmt) treefmtCommand;
in
treefmtCommand
