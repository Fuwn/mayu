{
  description = "Moe-Counter Compatible Website Hit Counter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    {
      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          packages = nixpkgs.legacyPackages.${system};
        in
        {
          default = packages.mkShell {
            buildInputs = with packages; [
              gleam
              rebar3
              erlang
            ];
          };
        }
      );
    };
}
