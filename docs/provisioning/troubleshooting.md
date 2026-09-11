# Provisioning Troubleshooting

## Inspect a host

The repository includes a read-only inspection helper:

```bash
./docs/provisioning/inspect-host.sh
```

It reports the operating system, IP addresses and routes when available, block
devices, memory, public SSH host keys, and a generated NixOS hardware
configuration when `nixos-generate-config` is installed. It does not read
private host keys or modify persistent machine state.

## Capture NixOS hardware configuration from another distribution

Nix is incompatible with SELinux enforcement in some host environments; a
Debian- or Ubuntu-based recovery image is generally easier for this temporary
inspection.

Install Nix, reopen the shell, and make `nixos-generate-config` available:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
nix-env -iE "_: with import <nixpkgs/nixos> { configuration = {}; }; \
  with config.system.build; [ nixos-generate-config ]"
nixos-generate-config --no-filesystems --root /tmp
cat /tmp/etc/nixos/hardware-configuration.nix
```

Treat generated hardware configuration as input for review, not as an
unconditionally reusable configuration. Networking and provider-specific boot
requirements may not be represented.

## Low-memory installations

Hosts should have at least 1 GiB of RAM. When the kexec installer is memory
constrained, create temporary zram from its console:

```bash
modprobe zram
zramctl /dev/zram0 --algorithm zstd \
  --size "$(($(grep -Po 'MemTotal:\s*\K\d+' /proc/meminfo) / 2))KiB"
mkswap -U clear /dev/zram0
swapon --discard --priority 100 /dev/zram0
```

This state is temporary and disappears after reboot. Confirm that `/dev/zram0`
is unused before running these commands.
