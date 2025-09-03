{ ... }:
let
  commonArgs = {
    root = ../../.;
    buildInputs = [ ];
    envVars = { };
  };
in
{
  inherit commonArgs;
}
