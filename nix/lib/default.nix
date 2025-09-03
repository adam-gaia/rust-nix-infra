{ inputs, ... }:
let

  mkTreefmt = import ./mktreefmt.nix;

  _mkCrate =
    pkgs: craneLib:
    {
      src,
      buildInputs,
      testInputs,

      # Additional environment variables can be set directly
      # MY_CUSTOM_VAR = "some value";
      envVars,

      clippyArgs,
    }:
    let
      commonCraneArgs = {
        inherit src buildInputs;
        strictDeps = true;
      }
      // envVars;

      # Build *just* the cargo dependencies, so we can reuse
      # all of that work (e.g. via cachix) when running in CI
      cargoArtifacts = craneLib.buildDepsOnly commonCraneArgs;

      # Export crane toolchain (cargo, clippy, rustfmt, etc) from crane's devShell to put in our own
      toolchain =
        let
          extras = with pkgs; [
            # TODO: some of these might be provided by crane toolchain
            rust-analyzer
            cargo-limit
            cargo-nextest
            cargo-dist
            cargo-tarpaulin
            cargo-deny
            cargo-llvm-cov
            cargo-release
            cargo-diet
          ];
        in
        (craneLib.devShell { }).nativeBuildInputs ++ extras;

      package = craneLib.buildPackage (
        commonCraneArgs
        // {
          inherit cargoArtifacts;
          strictDeps = true;
          doCheck = false; # Don't run tests as part of the build. We run tests with 'nix flake check .#<defaultpackage>'
        }
      );

      llvm-coverage =

        let

          craneLibLLvmTools = craneLib.overrideToolchain (
            inputs.fenix.packages.${pkgs.system}.complete.withComponents [
              "cargo"
              "rustc"
              "llvm-tools"
            ]
          );

          darwin = pkgs.writeShellApplication "unsupported" ''
            echo 'Darwin not supported for code coverage'
            exit 1
          '';

          llvm-coverage = craneLibLLvmTools.cargoLlvmCov (
            commonCraneArgs
            // {
              inherit cargoArtifacts;
            }
          );

        in
        if pkgs.stdenv.isLinux then llvm-coverage else darwin;

      cargo-audit =
        let
          advisory-db = inputs.advisory-db;
        in
        craneLib.cargoAudit {
          inherit src advisory-db;
        };

      cargo-clippy =
        let
          clippyArgs = if clippyArgs == null then "--all-targets -- --deny warnings" else clippyArgs;

        in
        craneLib.cargoClippy (
          commonCraneArgs
          // {
            inherit cargoArtifacts clippyArgs;
          }
        );

      cargo-deny = craneLib.cargoDeny {
        inherit src;
      };

      cargo-diet =
        let
          cargo-diet-wrapped = pkgs.writeShellApplication {
            name = "diet";
            runtimeInputs = [ pkgs.cargo-diet ];
            text = ''
              [[ "$(cargo diet "$@" | tail -n 1 )" == "There would be no change." ]] || exit 1
            '';
          };
        in
        craneLib.mkCargoDerivation (
          commonCraneArgs
          // {
            buildPhaseCargoCommand = "${cargo-diet-wrapped}/bin/diet --dry-run";
            inherit cargoArtifacts;
            pnameSuffix = "-diet";
            nativeBuildInputs = commonCraneArgs.nativeBuildInputs or [ ];
          }
        );

      cargo-nextest = craneLib.cargoNextest (
        commonCraneArgs
        // {
          inherit cargoArtifacts;
          partitions = 1;
          partitionType = "count";
          nativeBuildInputs = testInputs;
        }
      );

    in
    {
      inherit
        toolchain
        package
        llvm-coverage
        cargo-audit
        cargo-clippy
        cargo-deny
        cargo-diet
        cargo-nextest
        ;
    };

  /**
    Build a cargo workspace
  */
  mkWorkspace =
    pkgs:
    {
      root ? "./.",
      buildInputs ? [ ],
      testInputs ? [ ],
      envVars ? { },
      clippyArgs ? null,
    }:
    let
      inherit (pkgs) lib;
      craneLib = inputs.crane.mkLib pkgs;

      src = lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          # Default files from crane (Rust and cargo files)
          (craneLib.fileset.commonCargoSources root)
          # Also keep any markdown files (for trycmd)
          (lib.fileset.fileFilter (file: file.hasExt "md") root)
          # Test files (for trycmd)
          (lib.fileset.maybeMissing (root + "/tests"))
          # Test files specific to snaprun (for trycmd)
          (lib.fileset.maybeMissing (root + "/crates/snaprun/README.in"))
          (lib.fileset.maybeMissing (root + "/crates/snaprun/README.out"))
          # TODO: need a function to get each crate in a workspace, then we can add <crate>/tests all at once
          (lib.fileset.maybeMissing (root + "/crates/snaprun/tests"))
          (lib.fileset.maybeMissing (root + "/crates/different/tests"))
        ];
      };

    in
    _mkCrate pkgs craneLib {
      inherit
        src
        buildInputs
        testInputs
        envVars
        clippyArgs
        ;
    };

  # Build a cargo crate
  mkCrate =
    pkgs:
    {
      root ? "./.",
      buildInputs ? [ ],
      testInputs ? [ ],
      envVars ? { },
      clippyArgs ? null,
    }:
    let
      inherit (pkgs) lib;
      craneLib = inputs.crane.mkLib pkgs;

      src = lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          # Default files from crane (Rust and cargo files)
          (craneLib.fileset.commonCargoSources root)
          # Also keep any markdown files (for trycmd)
          (lib.fileset.fileFilter (file: file.hasExt "md") root)
          # Test files (for trycmd)
          (lib.fileset.maybeMissing (root + "/tests"))
        ];
      };
    in
    _mkCrate pkgs craneLib {
      inherit
        src
        buildInputs
        testInputs
        envVars
        clippyArgs
        ;
    };

in
{
  inherit
    mkCrate
    mkWorkspace
    mkTreefmt
    ;
}
