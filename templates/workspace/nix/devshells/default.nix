{
  flake,
  inputs,
  pkgs,
}:
let
  inherit (inputs.rust-nix-infra.lib) mkWorkspace;
  inherit (flake.lib) commonArgs;
  workspace = mkWorkspace pkgs commonArgs;
  inherit (workspace) toolchain;

  inherit (inputs.rust-nix-infra) mkTreefmt;
  treefmt = mkTreefmt pkgs flake ../treefmt.nix;
  inherit (treefmt) treefmtBin treefmtPrograms;

  pre-commit-check = inputs.pre-commit-hooks.lib.${pkgs.system}.run {
    src = ../.;
    hooks = {
      treefmt = {
        enable = true;
        package = treefmtBin;
      };
    };
  };
in
pkgs.mkShellNoCC {
  packages =
    with pkgs;
    [
      just
      bacon
      oranda
      vale
    ]
    # Include the extra packages we use to build our crate
    ++ commonArgs.buildInputs
    # Include rust toolchain
    ++ toolchain
    # Include treefmt and formatters
    ++ [ treefmtBin ]
    ++ treefmtPrograms;

  shellHook = ''
    export PRJ_ROOT="$(git rev-parse --show-toplevel)"

    # Add compiled rust bins to the path so the trycmd tests can access them
    export PATH="''${PRJ_ROOT}/target/debug:''${PATH}"

    # Create .pre-commit-config.yaml
    ${pre-commit-check.shellHook}
  '';
}
