# systems

## Overview

### Directory structure

```
.
├── functions  # utility functions
├── home       # home manager configurations
├── machines   # per device configurations
├── modules    # reuseable nix modules
├── overlays   # nixpkgs overlays
└── packages   # custom nix packages
```

### Machines

```
machines
├── wks-0       # macOS (aarch64)
├── srv-de-0    # NixOS server (x86_64)
├── srv-nl-0    # NixOS server (x86_64)
├── srv-sg-0    # NixOS server (x86_64)
├── srv-sg-1    # NixOS server (aarch64)
└── srv-sg-2    # NixOS server (x86_64)
```

## Usage (Justfile)

```
Available recipes:
    build                  # Build the configuration and show diff-closures [alias: b]
    default                # Default recipe to show available commands
    deploy target_host     # Deploy the configuration to a target host
    deploy-update-flakes   # Update flakes for the target hosts [alias: duf]
    deploy-update-pkgs     # Update unstable packages for the target hosts [alias: dup]
    deploy-update-pkgs-all # Update all packages for the target hosts [alias: dupa]
    list-generations       # List available generations
    rollback gen_num       # Rollback to a specific generation
    switch                 # Switch to the new configuration [alias: s]
    update-flakes          # Update flakes [alias: uf]
    update-pkgs            # Update unstable packages [alias: up]
    update-pkgs-all        # Update all packages [alias: upa]
    update-specific input  # Update specific flakes [alias: us]
```

## Deploy from Scratch

### How-tos

#### Get Hardware Configuration from Non-NixOS Host

> [!NOTE]
> Nix is not SELinux compatible, so it is better to choose a debian based distro (e.g., Ubuntu) to perform the steps below.

First install Nix on the host with:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then exit the terminal and open a new one. Run:

```bash
nix-env -iE "_: with import <nixpkgs/nixos> { configuration = {}; }; \
  with config.system.build; [ nixos-generate-config ]"
nixos-generate-config --no-filesystems --root /tmp
```

You will find the hardware configuration file under `/tmp/etc/nixos/hardware-configuration.nix`.

#### Perform Installation on Systems with Limited RAM

> [!NOTE]
> System need to have at least 1GB of RAM, or OOM might occur during installation.

After we enter nixos-installer after kexec, we can use below command to create a zram swap device:

```
modprobe zram
zramctl /dev/zram0 --algorithm zstd --size "$(($(grep -Po 'MemTotal:\s*\K\d+' /proc/meminfo)/2))KiB"
mkswap -U clear /dev/zram0
swapon --discard --priority 100 /dev/zram0
```

### Steps

#### macOS

1. Copy SSH host key (pubkey) to `secrets` flake and set the correct permissions.
   - You can generate the SSH host key pair with `sudo ssh-keygen -A` if you don't have one.
2. Use `ssh-keygen -t ed25519` to generate a temporary key pair.
3. Add the temporary key to the ssh-agent with `eval '$(ssh-agent -s)' && ssh-add ~/.ssh/id_ed25519`.
4. Add the temporary key (pubkey) to the GitHub.
   - Settings > SSH and GPG keys > New SSH key.
5. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/Users/spedon/.config`.
6. Install Nix (not Determinate Nix) with [determinate nix installer](https://github.com/DeterminateSystems/nix-installer).
7. Run `sudo nix run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch .#<configuration name>`.
   - Change 25.05 to the latest stable version.
   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Run the command under `/Users/spedon/.config/systems`.
8. You are good to go!
9. Remove the temporary key from the GitHub.

#### NixOS (server)

1. Get below information from the VPS.
   - The IPv4/IPv6 address and gateway (`ip addr && ip route show default && ip -6 route show default`).
   - The [hardware configuration](#get-hardware-configuration-from-non-nixos-host).
   - The SSH host key (`cat /etc/ssh/ssh_host_ed25519_key.pub`).
   - The disk to install NixOS on (`lsblk`).
2. Modify the configuration files under `machines/<configuration name>/` accordingly.
3. Copy the SSH host key (pubkey) to `secrets` flake and set the correct permissions.
4. Run

   ```
   nixos-anywhere \
      --flake .#<configuration name> \
      --kexec "$(nix build --print-out-paths github:Sped0n/nixos-images#packages.<arch>-linux.kexec-installer-nixos-unstable-noninteractive)/nixos-kexec-installer-noninteractive-<arch>-linux.tar.gz" \
      --copy-host-keys \
      --no-disko-deps \
      --target-host root@<ip address> \
      --ssh-option "PubkeyAuthentication=no"
   ```

   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Change `<arch>` to `x86_64` or `aarch64` depending on the architecture of the VPS.
   - Change `<ip address>` to the public IPv4 address of the VPS.
   - User need to have a nix environment to run this command.
   - Run the command under `/Users/spedon/.config/systems`.

5. Key in the root password (several times).
   - This is the original password before kexec.
6. After server kexec into nixos-installer, use below two ways to set a default password for root user.
   - Use VNC provided by the VPS provider and run `passwd` command.
   - Direct SSH (`ssh root@<ip address> -o PubkeyAuthentication=no`) and run `passwd` command.
7. [Setup zram](#perform-installation-on-systems-with-limited-ram) if needed.
8. Key in the root password (several times).
   - This is the new password set in step 7.
9. Wait for the command to finish.
10. You are good to go!
