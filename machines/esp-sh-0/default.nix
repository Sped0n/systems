{ functions, ... }:
{
  imports = [
    (functions.fromRoot "/hm/ubuntu")

    ./programs
  ];
}
