# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

let
  # SSH keys allowed in as root, as user and to Borg.
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ8Oq+mVW8+eKyLtpefLdnkAMRrmVeVDfotlYfdGhs74 user@secureblue"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHpe5YfySlIVBJjc2vm/sQ29JYLi3nD/kdOY+9NyNMZu user@desktop"
  ];

  hostName = "server.tail5c3838.ts.net";
  vaultDomain = "vault.garmany.me";
  calibreDomain = "calibre.garmany.me";

  # Plain root-only files, put there by hand. See README.
  secrets = "/var/lib/secrets";

  # What tailscale serve and cloudflared proxy to. See README.
  ports = {
    nextcloud = 8080;
    vaultwarden = 8081;
    miniflux = 8082;
    calibre = 8083;
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" "console=tty0" ];

  networking.hostName = "server"; # Define your hostname.

  services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/mnt/data/swapfile";
      size = 4 * 1024;
    }
  ];

  # journald cannot move to the SSD, which is unlocked long after it starts.
  services.journald.extraConfig = "SystemMaxUse=200M";

  security.apparmor.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.user = {
    isNormalUser = true;
    description = "Samuel Garmany";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = authorizedKeys;
  };
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  programs.fish = {
    enable = true;
    shellAliases = {
      cat = "bat";
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
    };
    interactiveShellInit = ''
      set -g fish_greeting

      starship init fish | source
      zoxide init --cmd cd fish | source
      fzf --fish | source

      # cd to wherever yazi was when it quit.
      # https://yazi-rs.github.io/docs/quick-start
      function y
      	set tmp (mktemp -t "yazi-cwd.XXXXXX")
      	command yazi $argv --cwd-file="$tmp"
      	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
      		builtin cd -- "$cwd"
      	end
      	command rm -f -- "$tmp"
      end
    '';
  };

  programs.git = {
    enable = true;
    config = {
      user.name = "Samuel Garmany";
      user.email = "65299214+samuel-garmany@users.noreply.github.com";
      init.defaultBranch = "main";
    };
  };

  # Lets the prebuilt language servers Mason downloads run.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc zlib ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Weekly `nixos-rebuild switch --upgrade`.
  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates = "weekly";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cryptsetup

    # terminal
    bat
    btop
    eza
    fd
    fzf
    gh
    jq
    lazygit
    ripgrep
    starship
    stow
    tldr
    unzip
    yazi
    zoxide

    # neovim, configured from my dotfiles (LazyVim)
    neovim
    gcc
    tree-sitter
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # AdGuard Home
  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    settings = {
      dns = {
        upstream_dns = [ "https://dns.quad9.net/dns-query" ];
        bootstrap_dns = [ "9.9.9.9" "149.112.112.112" "2620:fe::fe" ];
        enable_dnssec = true;
        edns_client_subnet.enabled = false;
      };
      querylog.interval = "24h";
    };
  };

  # DNS for the tailnet. adguardhome's openFirewall only covers the web UI.
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  # Borg. Every device gets its own repository underneath.
  services.borgbackup.repos.borgbackup = {
    path = "/mnt/data/borgbackup";
    inherit authorizedKeys;
    allowSubRepos = true;
  };

  # Calibre-Web, with the Kobo sync dependencies.
  services.calibre-web = {
    enable = true;
    package = pkgs.calibre-web.overridePythonAttrs (prev: {
      dependencies = prev.dependencies ++ prev.optional-dependencies.kobo;
    });
    listen.ip = "127.0.0.1";
    listen.port = 8084;
    options = {
      calibreLibrary = "/mnt/data/calibre-web";
      enableBookUploading = true;
      enableKepubify = true;
    };
  };

  # Kobo sync needs these headers. See README.
  # https://github.com/janeczku/calibre-web/wiki/Setup-Reverse-Proxy
  services.nginx.enable = true;
  services.nginx.virtualHosts.${calibreDomain} = {
    listen = [
      {
        addr = "127.0.0.1";
        port = ports.calibre;
      }
    ];
    extraConfig = ''
      client_max_body_size 20M;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.calibre-web.listen.port}";
      extraConfig = ''
        proxy_bind              $server_addr;
        proxy_set_header        Host            $host;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        X-Scheme        $http_x_forwarded_proto;
        proxy_set_header        X-Forwarded-Host $host;
      '';
    };
  };

  # Cloudflare Tunnel. services.cloudflared only covers locally-managed
  # tunnels; this one runs from a token, so the unit is the one
  # `cloudflared service install` writes.
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel client";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${lib.getExe pkgs.cloudflared} --no-autoupdate tunnel run --token-file ${secrets}/cloudflared-token";
      TimeoutStartSec = 15;
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Miniflux
  services.miniflux = {
    enable = true;
    adminCredentialsFile = "${secrets}/miniflux-admin-credentials";
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString ports.miniflux}";
      BASE_URL = "https://${hostName}:8446/";
      POLLING_SCHEDULER = "entry_frequency";
      CLEANUP_ARCHIVE_READ_DAYS = -1; # keep read entries
      FETCH_YOUTUBE_WATCH_TIME = 1;
    };
  };

  # Nextcloud
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud34;
    inherit hostName;
    datadir = "/mnt/data/nextcloud";
    https = true;
    configureRedis = true;
    database.createLocally = true;
    config.dbtype = "pgsql";
    config.adminpassFile = "${secrets}/nextcloud-adminpass";
    # secret and passwordsalt, carried over from the previous instance.
    secretFile = "${secrets}/nextcloud-secrets";
    settings = {
      overwriteprotocol = "https";
      "overwrite.cli.url" = "https://${hostName}/";
      trusted_proxies = [ "127.0.0.1" "::1" ];
      maintenance_window_start = 8; # UTC
      # The module default, plus HEIC for iPhone stills.
      enabledPreviewProviders = [
        "OC\\Preview\\PNG"
        "OC\\Preview\\JPEG"
        "OC\\Preview\\GIF"
        "OC\\Preview\\BMP"
        "OC\\Preview\\XBitmap"
        "OC\\Preview\\Krita"
        "OC\\Preview\\WebP"
        "OC\\Preview\\MarkDown"
        "OC\\Preview\\TXT"
        "OC\\Preview\\OpenDocument"
        "OC\\Preview\\HEIC"
      ];
    };
    extraApps = {
      inherit (pkgs.nextcloud34Packages.apps) calendar contacts tasks deck;
    };
    notify_push.enable = true;
  };

  services.nginx.virtualHosts.${hostName}.listen = [
    {
      addr = "127.0.0.1";
      port = ports.nextcloud;
    }
  ];

  # tailscale serve replaces x-forwarded-for, so notify_push cannot prove it
  # is a trusted proxy over the public hostname.
  systemd.services.nextcloud-notify_push.environment.NEXTCLOUD_URL =
    lib.mkForce "http://127.0.0.1:${toString ports.nextcloud}";

  # The default follows system.stateVersion and lands on 17; the database
  # was dumped from 18.
  services.postgresql.package = pkgs.postgresql_18;
  services.postgresqlBackup.enable = true;
  services.postgresqlBackup.location = "/mnt/data/backups/postgresql";

  # Cache and lock store only, so no snapshots.
  services.redis.servers.nextcloud.save = [ ];

  # Vaultwarden
  services.vaultwarden = {
    enable = true;
    domain = vaultDomain;
    backupDir = "/mnt/data/backups/vaultwarden";
    config = {
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = ports.vaultwarden;
    };
  };

  # /mnt/data is nofail, so units that use it have to wait for the mount
  # themselves. postgresql is absent because its module already does.
  systemd.services.borgbackup-repo-borgbackup.unitConfig.RequiresMountsFor = "/mnt/data/borgbackup";
  systemd.services.calibre-web.unitConfig.RequiresMountsFor = "/mnt/data/calibre-web";
  systemd.services.nextcloud-cron.unitConfig.RequiresMountsFor = "/mnt/data/nextcloud";
  systemd.services.nextcloud-setup.unitConfig.RequiresMountsFor = "/mnt/data/nextcloud";
  systemd.services.phpfpm-nextcloud.unitConfig.RequiresMountsFor = "/mnt/data/nextcloud";
  systemd.services.postgresqlBackup.unitConfig.RequiresMountsFor = "/mnt/data/backups/postgresql";
  systemd.services.vaultwarden.unitConfig.RequiresMountsFor = "/var/lib/vaultwarden";
  systemd.services.backup-vaultwarden.unitConfig.RequiresMountsFor = "/mnt/data/backups/vaultwarden";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
