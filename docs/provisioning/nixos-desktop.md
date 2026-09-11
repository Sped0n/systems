# NixOS Desktop Provisioning

> [!WARNING]
> This procedure is retained as a draft for a future NixOS desktop. It currently
> references no maintained `nixosConfigurations` machine target and may be
> outdated. Review every command, provide a real target and Disko layout, and
> verify backups before using it. There is intentionally no automation script.

1. Boot from the custom ISO. It is expected to include Firefox, Just, and
   agenix.
2. Use Firefox to authenticate to GitHub.
3. Skip the graphical installer, open a console, and run `sudo su`.
4. Generate a temporary SSH key and add it to an agent:

   ```bash
   ssh-keygen -t ed25519
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

5. Add the temporary public key to GitHub.
6. Clone the private secrets repository:

   ```bash
   cd /tmp
   git clone git@github.com:Sped0n/secrets.git
   ```

7. Add `/etc/ssh/ssh_host_ed25519_key.pub` as a secrets recipient, edit the
   required secrets with agenix, then commit and push that update.
8. Clone this repository into `/tmp/systems` and update its secrets input.
9. Review the selected machine's `disko.nix`, then run the destructive Disko
   operation only after independently verifying the target disk:

   ```bash
   nix --experimental-features "nix-command flakes" \
     run github:nix-community/disko/latest -- \
     --mode destroy,format,mount machines/<configuration>/disko.nix
   ```

10. Generate hardware information without filesystems:

    ```bash
    nixos-generate-config --no-filesystems --root /mnt
    ```

11. Preserve the installer host keys for age decryption:

    ```bash
    mkdir -m 755 -p /mnt/etc/ssh
    cp /etc/ssh/ssh_host_ed25519_key{,.pub} /mnt/etc/ssh/
    cp /etc/ssh/ssh_host_rsa_key{,.pub} /mnt/etc/ssh/
    ```

12. Move the repository into `/mnt/etc/nixos`, reconcile the target's hardware
    module with `/mnt/etc/nixos/hardware-configuration.nix`, and review the
    complete diff.
13. Install and reboot:

    ```bash
    nixos-install --flake path:.#<configuration>
    ```

14. Remove the temporary GitHub SSH credential.

Before this guide becomes current, add a maintained desktop machine target,
validate its Disko configuration in disposable hardware or a VM, and replace
all placeholders with its actual recovery procedure.
