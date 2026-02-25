# systems

## Overview

### Directory Structure

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
├── esp-0       # NixOS desktop (x86_64)
├── srv-de-0    # NixOS server (x86_64)
├── srv-hk-0    # NixOS server (x86_64)
├── srv-jp-0    # NixOS server (x86_64)
├── srv-nl-0    # NixOS server (x86_64)
├── srv-sg-0    # NixOS server (x86_64)
└── srv-sg-1    # NixOS server (aarch64)
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

## Provisioning

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
cat /tmp/etc/nixos/hardware-configuration.nix
```

#### Perform Installation on Systems with Limited RAM

> [!NOTE]
> System need to have at least 1GB of RAM, or OOM might occur during installation.

After we enter nixos-installer after kexec, we can use below command to create a zram swap device:

```bash
modprobe zram
zramctl /dev/zram0 --algorithm zstd --size "$(($(grep -Po 'MemTotal:\s*\K\d+' /proc/meminfo)/2))KiB"
mkswap -U clear /dev/zram0
swapon --discard --priority 100 /dev/zram0
```

#### Setup Agenix

> [!NOTE]
> User key is mainly for Home Manager agenix decryption, since the main user account doesn't have permission to read the machine key `/etc/ssh/ssh_host_ed25519_key`.
> Ans it is encrypted with machine key, kinda like the chain of trust.

> [!NOTE]
> You can generate the SSH host key pair with `sudo ssh-keygen -A` if you don't have one.

1. Generate an ed25519 key pair with `ssh-keygen -t ed25519` (aka user key).
2. Copy the machine key (pubkey) and the user key (pubkey) to the `secrets` flake.
3. Rekey after completing all the above steps (`sudo agenix -i /etc/ssh/ssh_host_ed25519_key -r`).

### Steps

#### macOS

1. Follow the steps in [setup agenix](#setup-agenix).
2. Use `ssh-keygen -t ed25519` to generate a temporary key pair.
3. Add the temporary key to the ssh-agent with `eval '$(ssh-agent -s)' && ssh-add ~/.ssh/id_ed25519`.
   - This key pair is different from "user key" in agenix setup.
4. Add the temporary key (pubkey) to the GitHub.
   - Settings > SSH and GPG keys > New SSH key.
5. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/Users/spedon/.config`.
6. Install Determinate Nix with the [installer](https://github.com/DeterminateSystems/nix-installer).
7. Run `sudo nix run nix-darwin/nix-darwin-<XX.XX>#darwin-rebuild -- switch .#<configuration name>`.
   - Change (XX.XX) to the current stable version (e.g., 25.05, 25.11).
   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Run the command under `/Users/spedon/.config/systems`.
8. Remove the temporary key from the GitHub.

#### NixOS (Server)

1. Get below information from the VPS.
   - The IPv4/IPv6 address and gateway (`ip addr && ip route show default && ip -6 route show default`).
   - The [hardware configuration](#get-hardware-configuration-from-non-nixos-host).
   - The SSH host key (`cat /etc/ssh/ssh_host_ed25519_key.pub`).
   - The disk to install NixOS on (`lsblk`).
2. Modify the configuration files under `machines/<configuration name>/` accordingly.
3. Follow the steps in [setup agenix](#setup-agenix).
4. `cd ~/.config/systems`.
5. Run `nixos-anywhere --flake .#<configuration name> --target-host root@<ip address> --copy-host-keys --no-disko-deps --ssh-option "PubkeyAuthentication=no"`.
   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Change `<ip address>` to the public IPv4 address of the VPS.
   - User need to have a nix environment to run this command.
6. Key in the root password (several times).
   - This is the original password before kexec.
7. After server kexec into nixos-installer, use below two ways to set a default password for root user.
   - Use VNC provided by the VPS provider and run `passwd` command.
   - Direct SSH (`ssh root@<ip address> -o PubkeyAuthentication=no`) and run `passwd` command.
8. [Setup zram](#perform-installation-on-systems-with-limited-ram) if needed.
9. Key in the root password (several times).
   - This is the new password set in step 7.
10. Wait for the command to finish.

#### NixOS (Desktop)

1. Download the ISO from [NixOS download page](https://nixos.org/download).
2. Boot from the ISO.
3. Skip the graphical installer and open console.
4. Run `sudo su` to switch to root.
5. Follow the steps in [setup agenix](#setup-agenix).
6. Use `ssh-keygen -t ed25519` to generate a temporary key pair.
7. Add the temporary key to the ssh-agent with `eval '$(ssh-agent -s)' && ssh-add ~/.ssh/id_ed25519`.
   - This key pair is different from "user key" in agenix setup.
8. Add the temporary key (pubkey) to the GitHub.
   - Settings > SSH and GPG keys > New SSH key.
9. `cd tmp`.
10. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
11. `nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount machines/<configuration name>/disko.nix`

- Change `<configuration name>` to the hostname of the machine you are deploying to.

12. Run `nixos-generate-config --no-filesystems --root /mnt`
13. Copy over existing `/etc/ssh/ssh_host_*` host keys to the installation (agenix machine key).
    - `mkdir -m 755 -p /mnt/etc/ssh`.
    - `cp /etc/ssh/ssh_host_ed25519_key /mnt/etc/ssh && cp /etc/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh`.
    - `cp /etc/ssh/ssh_host_rsa_key /mnt/etc/ssh && cp /etc/ssh/ssh_host_rsa_key.pub /mnt/etc/ssh`.
14. `mv /tmp/systems /mnt/etc/nixos && cd /mnt/etc/nixos/systems`.
15. Update `machines/<configuration name>/system.nix` according to `/mnt/etc/nixos/hardware-configuration.nix`.
16. Run `nixos-install --option extra-substituters https://install.determinate.systems?priority=100 --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= --flake .#<configuration name>`.
    - Change `<configuration name>` to the hostname of the machine you are deploying to.
17. Reboot (and unmount the ISO).
18. Remove the temporary key from the GitHub.
