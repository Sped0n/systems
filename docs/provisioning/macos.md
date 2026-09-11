# macOS Provisioning

This is the current bootstrap procedure for `darwinConfigurations.wks-0`.

1. Prepare the age recipients described in
   [Provisioning](README.md#secrets-and-age-identities).
2. Create and enroll a temporary GitHub SSH key as described in
   [Temporary repository access](README.md#temporary-repository-access).
3. Clone the repository under `~/.config`:

   ```bash
   cd ~/.config
   git clone git@github.com:Sped0n/systems.git
   cd systems
   ```

4. Install Nix with the
   [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer).
5. Bootstrap nix-darwin using the release matching this repository's pinned
   input. For the current configuration:

   ```bash
   sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
     switch --flake path:.#wks-0
   ```

6. After `darwin-rebuild` is installed, subsequent activation can use:

   ```bash
   sudo darwin-rebuild switch --flake path:.#wks-0
   ```

7. Remove the temporary GitHub SSH credential.
