{ ... }:
{
  programs = {
    mtr.enable = true;
    gnupg.agent.enable = true;
    ssh.startAgent = true;
  };
}
