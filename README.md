# nixos-server

/etc/nixos for my Raspberry Pi 4B.

    sudo nixos-rebuild switch

Upgrades itself weekly from the nixos-26.05 channel.

## Secrets

Not in git. Root-only files in /var/lib/secrets, copies in Bitwarden.

    cloudflared-token
    miniflux-admin-credentials   ADMIN_USERNAME= and ADMIN_PASSWORD=
    nextcloud-adminpass
    nextcloud-secrets            json, secret and passwordsalt

## tailscale serve

Not in the config either.

    tailscale serve --bg --https=443  8080   # nextcloud
    tailscale serve --bg --https=8443 3000   # adguard
    tailscale serve --bg --https=8444 8081   # vaultwarden
    tailscale serve --bg --https=8445 8083   # calibre-web
    tailscale serve --bg --https=8446 8082   # miniflux

## Kobo

Set up sync from calibre.garmany.me, not localhost. It builds the sync URL
from whatever address you opened it on.

## Borg

    ssh://borg@server.tail5c3838.ts.net/./<device>

One repo per device. New devices need their ssh key added at the top of
configuration.nix. Pika Backup handles the schedule.
