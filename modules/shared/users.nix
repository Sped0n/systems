{ vars, ... }:
{
  users.users."${vars.username}" = {
    home = vars.home;
    name = "${vars.username}";
  };
}
