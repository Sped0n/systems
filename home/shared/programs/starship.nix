{lib, ...}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = lib.concatStrings [
        "$all"
        "$fill"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];
      command_timeout = 1000;
      fill = {
        symbol = " ";
      };
      directory = {
        truncate_to_repo = false;
        truncation_length = 0;
        read_only = " ro";
      };
      git_commit = {
        tag_symbol = " tag ";
      };
      git_status = {
        ahead = ">$count";
        behind = "$count<";
        diverged = "$behind_count<|>$ahead_count";
        renamed = "r";
        deleted = "x";
      };
      hostname = {
        ssh_symbol = "";
        format = "[\\($hostname\\)]($style) ";
        style = "bold dimmed red";
      };
      username = {
        disabled = true;
      };

      aws = {
        symbol = "aws ";
        disabled = true;
      };
      azure = {symbol = "az ";};
      buf = {symbol = "buf ";};
      bun = {symbol = "bun ";};
      cobol = {symbol = "cobol ";};
      conda = {symbol = "conda ";};
      container = {symbol = "container ";};
      crystal = {symbol = "cr ";};
      cmake = {symbol = "cmake ";};
      daml = {symbol = "daml ";};
      dart = {symbol = "dart ";};
      deno = {symbol = "deno ";};
      dotnet = {symbol = ".NET ";};
      docker_context = {symbol = "docker ";};
      elixir = {symbol = "exs ";};
      elm = {symbol = "elm ";};
      fennel = {symbol = "fnl ";};
      fossil_branch = {symbol = "fossil ";};
      gcloud = {symbol = "gcp ";};
      git_branch = {symbol = "git ";};
      gleam = {symbol = "gleam ";};
      golang = {symbol = "go ";};
      gradle = {symbol = "gradle ";};
      guix_shell = {symbol = "guix ";};
      haskell = {symbol = "haskell ";};
      helm = {symbol = "helm ";};
      hg_branch = {symbol = "hg ";};
      java = {symbol = "java ";};
      julia = {symbol = "jl ";};
      kotlin = {symbol = "kt ";};
      lua = {symbol = "lua ";};
      nodejs = {symbol = "nodejs ";};
      memory_usage = {symbol = "memory ";};
      meson = {symbol = "meson ";};
      nats = {symbol = "nats ";};
      nim = {symbol = "nim ";};
      nix_shell = {symbol = "nix ";};
      ocaml = {symbol = "ml ";};
      opa = {symbol = "opa ";};
      package = {symbol = "pkg ";};
      perl = {symbol = "pl ";};
      php = {symbol = "php ";};
      pijul_channel = {symbol = "pijul ";};
      pulumi = {symbol = "pulumi ";};
      purescript = {symbol = "purs ";};
      python = {symbol = "py ";};
      quarto = {symbol = "quarto ";};
      raku = {symbol = "raku ";};
      rlang = {symbol = "r ";};
      ruby = {symbol = "rb ";};
      rust = {symbol = "rs ";};
      scala = {symbol = "scala ";};
      spack = {symbol = "spack ";};
      solidity = {symbol = "solidity ";};
      status = {symbol = "[x](bold red) ";};
      sudo = {symbol = "sudo ";};
      swift = {symbol = "swift ";};
      typst = {symbol = "typst ";};
      terraform = {symbol = "terraform ";};
      zig = {symbol = "zig ";};

      os = {
        symbols = {
          AIX = "aix ";
          Alpaquita = "alq ";
          AlmaLinux = "alma ";
          Alpine = "alp ";
          Amazon = "amz ";
          Android = "andr ";
          Arch = "rch ";
          Artix = "atx ";
          CachyOS = "cach ";
          CentOS = "cent ";
          Debian = "deb ";
          DragonFly = "dfbsd ";
          Emscripten = "emsc ";
          EndeavourOS = "ndev ";
          Fedora = "fed ";
          FreeBSD = "fbsd ";
          Garuda = "garu ";
          Gentoo = "gent ";
          HardenedBSD = "hbsd ";
          Illumos = "lum ";
          Kali = "kali ";
          Linux = "lnx ";
          Mabox = "mbox ";
          Macos = "mac ";
          Manjaro = "mjo ";
          Mariner = "mrn ";
          MidnightBSD = "mid ";
          Mint = "mint ";
          NetBSD = "nbsd ";
          NixOS = "nix ";
          Nobara = "nbra ";
          OpenBSD = "obsd ";
          OpenCloudOS = "ocos ";
          openEuler = "oeul ";
          openSUSE = "osuse ";
          OracleLinux = "orac ";
          Pop = "pop ";
          Raspbian = "rasp ";
          Redhat = "rhl ";
          RedHatEnterprise = "rhel ";
          RockyLinux = "rky ";
          Redox = "redox ";
          Solus = "sol ";
          SUSE = "suse ";
          Ubuntu = "ubnt ";
          Ultramarine = "ultm ";
          Unknown = "unk ";
          Uos = "uos ";
          Void = "void ";
          Windows = "win ";
        };
      };
    };
  };
}
