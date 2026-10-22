# nixos-server

This repo holds the /etc/nixos for my Raspberry Pi 4B server. When built, it provides my cloud services including the following:

- **[Nextcloud](https://nextcloud.com/):** Storage, calendar, and contacts.
    - It also integrates well with [Joplin](https://joplinapp.org/) and [Zotero](https://www.zotero.org/), so it stores my notes and academic paper annotations.
- **[Vaultwarden](https://vaultwarden.com/):** Password manager written in Rust and compatible with Bitwarden clients.
- **[Calibre-Web](https://github.com/janeczku/calibre-web):** Hosts my ebook library with inbuilt support for my Kobo ereader. Uses the Calibre file structure.
- **[Miniflux](https://miniflux.app/):** A simple RSS feed for following blogs and news.
- **[Adguard Home](https://adguard.com/en/adguard-home/overview.html):** Provides DNS-level ad blocking across my tailnet.

## Configuration Changes and Upgrades

    sudo nixos-rebuild switch

Automatically upgrades itself weekly, with reboots for kernel updates. Manual upgrades can be performed using:

    sudo nixos-rebuild switch --upgrade

## Future Directions

I'm interested in eventually replacing Tailscale with plain Wireguard, adding forgejo, and moving my personal site to this server in order to move away from GitHub and GitHub pages, respectively. I would also like a dedicated photo storage service, though this would require a hardware upgrade (I have tried on the pi, it is not good).

## Notes

> [!IMPORTANT]
> Below is a list of config that isn't declared in Nix:

## tailscale serve

    tailscale serve --bg --https=443  8080   # nextcloud
    tailscale serve --bg --https=8443 3000   # adguard home
    tailscale serve --bg --https=8444 8081   # vaultwarden
    tailscale serve --bg --https=8445 8083   # calibre-web
    tailscale serve --bg --https=8446 8082   # miniflux

## Borg

    ssh://borg@server.tail5c3838.ts.net/./<device>

One repo per device. New devices need their ssh key included at the top of
configuration.nix.
