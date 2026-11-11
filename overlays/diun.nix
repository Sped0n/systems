# TODO: Remove once https://github.com/NixOS/nixpkgs/pull/586543 reaches the pinned nixpkgs inputs.
{ ... }:
final: prev: {
  diun = prev.diun.override {
    buildGoModule = final.buildGo126Module;
  };
}
