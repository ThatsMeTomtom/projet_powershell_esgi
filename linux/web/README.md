# Linux Web Stack

This Docker stack runs two websites on the Debian server:

- Public website: `public.local`
- Intranet website: `intranet.local`

## Start

```bash
cd linux/web
bash start.sh
```

This installs Docker automatically on first run (via `../install-docker.sh`) if needed,
pulls the latest code, and starts the stack.

To deploy DHCP and the web stack together in one command, run `bash linux/deploy.sh`.

## Stop

```bash
docker compose down
```

## Test locally

Add the following to `/etc/hosts` on the Debian host or your workstation:

```text
127.0.0.1 public.local
127.0.0.1 intranet.local
```

Then visit:

- http://public.local/
- http://intranet.local/

## Notes

- The reverse proxy routes requests by hostname.
- Containers communicate over a dedicated Docker network: `web-network`.
- This keeps both the public site and intranet site on one Debian server.
- For a real deployment, replace `public.local` and `intranet.local` with actual DNS names.
