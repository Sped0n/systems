{ inputs, ... }:
final: prev:
let
  dix = inputs.determinate.inputs.nix.packages."${prev.stdenv.system}".default;
in
{
  agenix-cli = inputs.agenix.packages."${prev.stdenv.system}".default.override {
    nix = dix;
  };

  nixos-anywhere = prev.nixos-anywhere.override { nix = dix; };

  nixos-rebuild-ng = prev.nixos-rebuild-ng.override { nix = dix; };

  nixpkgs-review = prev.nixpkgs-review.override { nix = dix; };
  nixpkgs-reviewFull = prev.nixpkgs-reviewFull.override {
    nixpkgs-review = prev.nixpkgs-review.override { nix = dix; };
  };

  nix-direnv = prev.nix-direnv.override { nix = dix; };
}
