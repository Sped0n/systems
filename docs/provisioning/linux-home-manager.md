# Linux Home Manager Provisioning

This is the current procedure for the standalone `homeConfigurations.esp-0`
configuration on an existing Linux distribution. Home Manager does not manage
the host's bootloader, disks, system users, system package manager, or base SSH
configuration.

## Prerequisites

1. Install Nix in multi-user mode using the
   [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
   or another trusted installer.
2. Ensure the target user is permitted to use the daemon. Confirm the effective
   setting with `nix show-config | grep '^trusted-users'` and update the host's
   Nix configuration when necessary.
3. Prepare the user and machine age recipients described in
   [Provisioning](README.md#secrets-and-age-identities).
4. Clone this repository as `~/.config/systems`.
5. Make the private `secrets` flake input accessible over SSH.

## Activate

From the repository root, run:

```bash
activation_package="$(nix build --no-link --print-out-paths \
  'path:.#homeConfigurations."esp-0".activationPackage')"
"$activation_package/activate"
```

This builds and runs the activation package pinned by the repository flake
without creating a `result` link.

After the first activation, the managed `home-manager` command is available;
subsequent updates can run `home-manager switch --flake path:.#esp-0`.

## Ubuntu workstation setup

The current workstation uses a small distribution-owned baseline that cannot be
expressed through standalone Home Manager:

- `ssh-askpass-gnome`, `zram-tools`, and `gnome-screenshot` from APT;
- zram using 50% of RAM, `lz4`, and swap priority 100;
- membership in `dialout` and `plugdev` for development hardware;
- IPv6 router advertisement acceptance and route-information prefixes up to
  `/128` on the primary uplink;
- Solaar and Espressif OpenOCD udev rules, sourced from the installed Nix and
  ESP-IDF tool packages rather than copied into this repository;
- the workstation user listed in the Nix daemon's `trusted-users` setting.

Inspect a fresh Ubuntu host without changing it:

```bash
./docs/provisioning/ubuntu-workstation.sh --check
```

After reviewing the report, apply the package, zram, group, and discovered udev
rule changes with:

```bash
./docs/provisioning/ubuntu-workstation.sh --apply
```

The helper selects the interface carrying the IPv6 default route, falling back
to the IPv4 default route. Override it when provisioning an inactive Wi-Fi
uplink or another future primary interface:

```bash
./docs/provisioning/ubuntu-workstation.sh --check --interface <interface>
./docs/provisioning/ubuntu-workstation.sh --apply --interface <interface>
```

The settings are intentionally interface-specific. Applying `accept_ra=2`
globally would also affect Docker bridges, virtual Ethernet devices, VPNs, and
other interfaces that should not accept router advertisements. The helper writes
a sysctl drop-in and, when NetworkManager is active, a dispatcher hook because
NetworkManager may reset per-interface IPv6 sysctls when reconnecting.

The apply mode describes its changes, requires typing `apply`, and uses `sudo`
only after confirmation. It is idempotent and deliberately does not perform a
distribution upgrade, install Docker, alter Nix daemon trust, or weaken AppArmor.
Run it again after Home Manager and ESP-IDF tools are installed so their udev
rules can be discovered.

## Manual host policy

Keep operating-system upgrades and Docker installation in the distribution's
normal administration workflow. Add the user to the `docker` group only when a
system Docker daemon is intentionally installed.

Ubuntu may restrict unprivileged user namespaces through AppArmor. The current
workstation sets `kernel.apparmor_restrict_unprivileged_userns=0`, but this
reduces sandboxing and is therefore not automated. Change it only when a
required Nix-installed desktop application cannot start and after reviewing the
security impact.
