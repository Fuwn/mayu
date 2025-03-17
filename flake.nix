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

        pkgs = import nixpkgs {
          inherit system;

          overlays = [
            nix-gleam.overlays.default
          ];
        };
      in
      {
        packages = {
          default = pkgs.buildGleamApplication {
            src = gitignoreSource ./.;

            rebar3Package = pkgs.rebar3WithPlugins {
              plugins = with pkgs.beamPackages; [ pc ];
            };
          };

          mayu = self.packages.${system}.default;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gleam
            rebar3
	    escript
          ];
        };
      }
    );
}
