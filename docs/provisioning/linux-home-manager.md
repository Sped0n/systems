# Linux Home Manager provisioning

This guide provisions `homeConfigurations.esp-0` on Ubuntu. Home Manager does
not manage the host's bootloader, disks, system users, package manager, or base
SSH configuration.

## Prerequisites

1. Install Nix in multi-user mode using the
   [NixOS Nix Installer](https://github.com/NixOS/nix-installer).
2. Check daemon access with `nix store ping --store daemon --json`. Its `trusted`
   field reports daemon trust. Client-side `trusted-users` settings do not
   establish it.
3. Prepare the user and machine age recipients described in
   [Provisioning](README.md#secrets-and-age-identities).
4. Clone this repository as `~/.config/systems` and make the private `secrets`
   flake input accessible over SSH.

## Activate

Run from the repository root as the workstation user, not root:

```bash
activation_package="$(nix build --no-link --print-out-paths \
  'path:.#homeConfigurations."esp-0".activationPackage')"
"$activation_package/activate"
```

This uses the repository's pinned activation package without creating a `result`
link. After the first activation, update with
`home-manager switch --flake path:.#esp-0`.

Review activation warnings for any remaining host setup. Ubuntu checks live in
[`hm/ubuntu/`](../../hm/ubuntu/).
