# Linux Home Manager provisioning

This guide provisions `homeConfigurations.esp-sh-0` on Ubuntu. Home Manager does
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
  'path:.#homeConfigurations."esp-sh-0".activationPackage')"
"$activation_package/activate"
```

This uses the repository's pinned activation package without creating a `result`
link.

## Set the local configuration name

`just hs` reads the configuration name from `~/.config/systems-local`.
Create this file on each machine. Use `esp-sh-0` in Shanghai and `esp-sg-0` in
Singapore.

```bash
mkdir -p ~/.config
printf '%s\n' esp-sh-0 > ~/.config/systems-local
```

Keep this file local to each machine. It does not change the OS hostname.

After the first activation, run `just hs` from the repository root. It switches
to the configuration named in the file.

If the file is missing or unreadable, `just hs` exits with setup instructions.
It also rejects empty files, invalid names, and names absent from
`homeConfigurations`. `--force` does not bypass these checks.

An explicit name must match the file. For example, `just hs esp-sg-0` fails on a
machine whose file contains `esp-sh-0`. Use `just hs esp-sg-0 --force` to override
this check. The command prints a warning with both names. It still rejects names
absent from `homeConfigurations`.

Direct `home-manager switch` and activation-package commands do not check this
file.

Review activation warnings for any remaining host setup. Ubuntu checks live in
[`hm/ubuntu/`](../../hm/ubuntu/).
