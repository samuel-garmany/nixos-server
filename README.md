# server

`/etc/nixos` for my Raspberry Pi 4B: Nextcloud, Vaultwarden, Calibre-Web,
Miniflux, AdGuard Home, Borg and a Cloudflare tunnel. Channel is `nixos-26.05`.

```
sudo nixos-rebuild switch
```

It upgrades itself weekly. Config changes need a `git pull` and a rebuild.

## Secrets

Not in git. Four files in `/var/lib/secrets`, root-only:

```
cloudflared-token            # the token
miniflux-admin-credentials   # ADMIN_USERNAME=... and ADMIN_PASSWORD=...
nextcloud-adminpass          # the password
nextcloud-secrets            # JSON: secret and passwordsalt
```

```
sudo install -d -m 700 /var/lib/secrets
sudo install -m 400 <file> /var/lib/secrets/
```

Copies are in Bitwarden.

## tailscale serve

Lives in tailscaled's state.

```
tailscale serve --bg --https=443  8080   # nextcloud
tailscale serve --bg --https=8443 3000   # adguard home
tailscale serve --bg --https=8444 8081   # vaultwarden
tailscale serve --bg --https=8446 8082   # miniflux

tailscale serve status
tailscale serve --https=<port> off
```

## Kobo sync

Open Calibre-Web through the public hostname when setting it up; it builds the
sync endpoint from the URL it was reached on.
https://github.com/janeczku/calibre-web/wiki/Kobo-Integration

It reads `X-Scheme`, not `X-Forwarded-Proto`, and only trusts the proxy when
`X-Forwarded-Host` is set. That is why nginx sits in front of it. Without
those headers book downloads fail.

## Borg

```
ssh://borg@server.tail5c3838.ts.net/./<device>
```

One repository per device, since Borg locks the whole repository while it
writes. A new device needs its SSH key at the top of `configuration.nix`.

Pika Backup does the scheduling and pruning on each device. Nothing checks
the repositories automatically, so run an integrity check from Pika now and
then. The encryption key is in the repository (`repokey`); the passphrase is
the only way back in.
