# Deploy from Scratch

## How-tos

### Get Hardware Configuration from Non-NixOS Host

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

## Steps

### macOS

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

### NixOS (server)

1. Reset the VPS from the admin console that you got from the provider.
   - You need to install a distro that DON'T use SELinux.
2. Get below information from the VPS.
   - The IPv4/IPv6 address and gateway.
   - The [hardware configuration](#get-hardware-configuration-from-non-nixos-host).
   - The SSH host key (pubkey).
3. Modify the configuration files under `machines/<configuration name>/` accordingly.
4. Copy the SSH host key (pubkey) to `secrets` flake and set the correct permissions.
5. Run

   ```
   nix run github:nix-community/nixos-anywhere -- \
      --flake .#<configuration name> \
      --kexec "$(nix build --print-out-paths github:Sped0n/nixos-images#packages.<arch>-linux.kexec-installer-nixos-unstable-noninteractive)/nixos-kexec-installer-noninteractive-<arch>-linux.tar.gz" \
      --copy-host-keys \
      --no-disko-deps \
      --target-host root@<ip address>
   ```

   - Change `<configuration name>` to the hostname of the machine you are deploying to.
   - Change `<arch>` to `x86_64` or `aarch64` depending on the architecture of the VPS.
   - Change `<ip address>` to the public IPv4 address of the VPS.
   - User need to have a nix environment to run this command.
   - Run the command under `/Users/spedon/.config/systems`.

6. Key in the password of the VPS if prompted.
7. Wait for the command to finish.
8. You are good to go!

### NixOS (desktop)

1. Download the ISO from [NixOS download page](https://nixos.org/download).
2. Boot from the ISO.
3. Skip the graphical installer and open console.
4. Run `sudo su` to switch to root.
5. Repeat step 1 to 4 of [macOS](#macos).
6. Clone the repo with `git clone git@github.com:Sped0n/systems.git`.
   - Run the command under `/tmp`.
7. Find where the target configuration's `disko.nix` located and run `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount <path to disko.nix>`
8. Run `nixos-generate-config --no-filesystems --root /mnt`
9. Move the repo to with `mv /tmp/systems /mnt/etc/nixos`.
10. Place the agenix identity key to `/mnt/etc/nixos/id_agenix`.
    - `chmod` the key to 0500.
11. Run `nixos-install --flake .#<configuration name>`.
    - Change `<configuration name>` to the hostname of the machine you are deploying to.
    - Run the command under `/mnt/etc/nixos`.
12. Reboot.
13. You are good to go!
14. Remove the temporary key from the GitHub.
