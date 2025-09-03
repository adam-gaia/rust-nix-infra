{
  inputs,
  ...
}:
let
  mkTreefmt =
    pkgs: src: treefmtFilePath:
    let
      inherit (pkgs) lib;

      # Treefmt doesn't easily expose the programs with out its flake-parts module (as far as I can tell)
      # This snipit, modified from their default.nix, lets us grab the programs after building with our treefmt config
      treefmt-module-builder =
        nixpkgs: configuration:
        let
          mod = inputs.treefmt-nix.lib.evalModule nixpkgs configuration;
        in
        mod.config.build;
      treefmtModule = treefmt-module-builder pkgs (import treefmtFilePath);
      treefmtBin = treefmtModule.wrapper;
      treefmtPrograms = lib.attrValues treefmtModule.programs;
      treefmtCommand =
        pkgs.runCommand "treefmt"
          {
            inherit src;
            nativeBuildInputs = [ treefmtBin ] ++ treefmtPrograms;
          }
          ''
            cd $src
            treefmt --ci
            touch $out
          '';

    in
    {
      inherit treefmtBin treefmtPrograms treefmtCommand;
    };
in
mkTreefmt
