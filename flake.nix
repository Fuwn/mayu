{
  description = "Moe-Counter Compatible Website Hit Counter";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-gleam.url = "github:arnarg/nix-gleam";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, flake-utils, nix-gleam, gitignore, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            nix-gleam.overlays.default
          ];
        };
        inherit (gitignore.lib) gitignoreSource;
      in
      {
        packages.default = pkgs.buildGleamApplication {
          src = gitignoreSource ./.;
          rebar3Package = pkgs.rebar3WithPlugins {
            plugins = with pkgs.beamPackages; [ pc ];
          };
        };
        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.gleam pkgs.rebar3 ];
        };
      }
    );
}
