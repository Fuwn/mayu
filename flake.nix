{
  description = "Moe-Counter Compatible Website Hit Counter";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nix-gleam.url = "github:arnarg/nix-gleam";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      flake-utils,
      gitignore,
      nix-gleam,
      nixpkgs,
      self,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (gitignore.lib) gitignoreSource;

        packages = import nixpkgs { inherit system; };
        inherit (packages.callPackage "${nix-gleam}/builder" { }) buildGleamApplication;
      in
      {
        packages = {
          default = buildGleamApplication {
            src = gitignoreSource ./.;

            rebar3Package = packages.rebar3WithPlugins {
              plugins = with packages.beamPackages; [ pc ];
            };
          };

          mayu = self.packages.${system}.default;
        };

        devShells.default = packages.mkShell {
          buildInputs = with packages; [
            gleam
            rebar3
            erlang
          ];
        };
      }
    );
}
