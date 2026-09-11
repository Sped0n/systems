# NixOS Server Provisioning

This procedure provisions one of the current `srv-*` NixOS configurations with
nixos-anywhere. It destroys and recreates storage according to the target's
tracked `disko.nix`.

> [!CAUTION]
> Confirm the target host, configuration, provider console access, backups, and
> disk layout before continuing. A correct hostname with an incorrect Disko
> configuration can permanently destroy the wrong data.

## Gather target information

Collect the following from the existing VPS:

- IPv4 and IPv6 addresses, routes, and gateways;
- hardware details required by `machines/<configuration>/system.nix`;
- `/etc/ssh/ssh_host_ed25519_key.pub`;
- the exact installation disk and provider recovery procedure.

The read-only helper prints the available facts when copied to and run on the
target:

```bash
./docs/provisioning/inspect-host.sh
```

See [Troubleshooting](troubleshooting.md) when Nix tooling is unavailable on the
original operating system.

## Prepare configuration and secrets

1. Update `machines/<configuration>/system.nix` and `disko.nix` with the
   collected hardware, networking, and disk information.
2. Add the target's host public key to the private secrets repository and rekey
   as described in [Provisioning](README.md#secrets-and-age-identities).
3. Verify provider console or VNC access before starting.

## Install

From a machine with Nix, nixos-anywhere, repository access, and the required age
identity, run:

```bash
nixos-anywhere \
  --flake path:.#<configuration> \
  --target-host root@<ip-address> \
  --copy-host-keys \
  --no-disko-deps \
  --ssh-option "PubkeyAuthentication=no"
```

This preserves the target's host keys and enables password authentication for
bootstrap. Review the selected configuration's `disko.nix` immediately before
running it.

During installation:

1. Enter the original VPS root password when prompted.
2. After kexec enters the installer, set a temporary root password through the
   provider console or direct SSH if required.
3. Configure temporary zram using
   [Troubleshooting](troubleshooting.md#low-memory-installations) when needed.
4. Enter the installer password when nixos-anywhere reconnects.
5. Wait for installation and reboot to complete before removing recovery
   access.
