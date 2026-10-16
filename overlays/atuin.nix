{ ... }:
final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # Temporary backport of https://github.com/NixOS/nixpkgs/pull/574509.
  # Remove once the pinned nixpkgs inputs include the fix.
  atuin = prev.atuin.overrideAttrs (old: {
    env = (old.env or { }) // {
      # The test harness clears the environment; a bash-named wrapper keeps
      # the host's /etc/bashrc from replacing the test PATH on nix-darwin.
      ATUIN_E2E_BASH = prev.lib.getExe (
        prev.writeShellScriptBin "bash" ''
          NOSYSBASHRC=1 exec ${prev.lib.getExe prev.bashInteractive} "$@"
        ''
      );
    };
  });
}
