{ ... }:
{
  # Enable CUPS to print documents
  services.printing.enable = true;
  # Display
  services.xserver.resolutions = [
    {
      x = 1920;
      y = 1080;
    }
  ];
  # nix-ld
  programs.nix-ld.enable = true;
}
