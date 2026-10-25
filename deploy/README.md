# Deploy

Collarbell runs on one server, a shared work server of other projects too. Address:
**<https://collarbell.example.com>**. It's a free [sslip.io](https://sslip.io) name that points to the
server's IP; a real domain comes later (see below).

| Path | What |
|---|---|
| `/` | the landing (`landing/`, Astro), English; Russian under `/ru/` |
| `/api/v1/…` | the API |
| `/health` | `Healthy` when the API and its database answer (the app and the deploy script ask it) |
| `/collarbell/…` | file downloads by signed links from the API (bucket `collarbell`) |
| `/admin/` | the owner's admin (`admin/`, React): numbers, people, the visor; admins only (`make-admin`, below) |
| `/app/` | the web app for pet owners (`web/`, React): Today, pets, visits; the same accounts as the phone app |
| `/hubs/household` | live updates for the app's open screens (SignalR over a WebSocket; both nginx pass the upgrade on) |

## What runs on the server

Everything lives in **`/opt/collarbell`** (root only, `chmod 700`), in docker compose project **`collarbell`**:

```text
/opt/collarbell/
  .env          secrets (env.example lists them), chmod 600
  .ssh/         the server's read-only deploy key for the GitHub repository
  src/          a clone of the repository at the running commit
  deploy        the deploy command (a copy of deploy.sh)
  deployed      the commit that runs now
  deploy.log    output of every deploy
  backups/      nightly copies, 14 days
```

Containers (`compose.yml`): **web** (nginx with the landing and the routes, `nginx.conf`), **api**, **postgres**,
**storage** (SeaweedFS, S3 API), **backup**. Only `web` is published, and only on `127.0.0.1:5180`; the database
and the storage are reachable only inside the project's network.

Shared with the other projects, and nothing else:
- `/etc/nginx/sites-available/collarbell`, enabled as `sites-enabled/zz-collarbell` (a copy of
  `host-nginx.conf`): HTTPS for the address, then everything to `127.0.0.1:5180`. Deploys never change it.
- the Let's Encrypt certificate of the address (certbot, webroot `/var/www/html`, renewed by `certbot.timer`
  with `systemctl reload nginx`);
- one line in root's `~/.ssh/authorized_keys`: the GitHub Actions key, which may only run `/opt/collarbell/deploy`.

Don't change other projects' files, ports or containers, the firewall or SSH settings.

## How a deploy goes

A push to `main` → CI (`.github/workflows/ci.yml`) → when it passes, **Deploy** (`deploy.yml`) connects over SSH
with its key and passes the commit. On the server `deploy.sh`:
1. checks that the commit is on `main` and isn't older than the one that runs;
2. checks it out in `src/` and runs `release.sh`, which:
   - builds the images while the old containers keep running (the old images stay as `:previous`);
   - runs `api migrate`: the new version updates the database and creates the bucket if needed. If this fails,
     nothing is replaced;
   - starts the new containers and waits up to two minutes for `/health`. No answer: the previous images start
     again and the deploy fails (red in Actions);
3. writes the commit to `deployed` and the output to `deploy.log`.

Migrations must stay backward compatible (add first, remove later), so the previous version still works after a
rollback (system-design.md, 3.8).

By hand:
- the newest `main`: GitHub → Actions → Deploy → Run workflow;
- on the server: `/opt/collarbell/deploy <full commit sha>`.

## Everyday commands (on the server)

```bash
cd /opt/collarbell/src/deploy
alias cbc='docker compose --env-file /opt/collarbell/.env'
cbc ps                         # what runs
cbc logs -f --tail 100 api     # API log
cbc restart api                # after editing .env
tail -50 /opt/collarbell/deploy.log
```

Roll back to the previous version by hand:

```bash
docker tag collarbell-api:previous collarbell-api:current
docker tag collarbell-web:previous collarbell-web:current
cbc up -d
```

## Admin

The admin at `/admin/` lets in only users marked as admins. Mark one (they must have signed in to the app once):

```bash
cbc run --rm --no-deps api make-admin <e-mail>
```

Alerts go to Telegram when `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are in `.env` (then `cbc up -d api`); without
them they are only in the API log.

A deletion asked for by e-mail (the landing's "Delete your account" page; people with the app use More → Delete
account): first see what it would do to each household, then delete. It deletes the Firebase sign-in account too
(with `FIREBASE_SERVICE_ACCOUNT`, the pushes' key); if Firebase doesn't answer, the API tries again every 10 minutes.

```bash
cbc run --rm --no-deps api delete-account <e-mail>          # what would happen, nothing deleted
cbc run --rm --no-deps api delete-account <e-mail> --yes    # deletes
```

## Secrets

`/opt/collarbell/.env`, see `env.example`. The database password and the storage keys were generated on the
server. The Gemini key and the Firebase service account key are the same as in the AppHost's user secrets on the
Mac (README, "Push notifications"). After a change: `cbc up -d api`.

## Backups

The `backup` container copies the database (`pg_dump`, `db-YYYY-MM-DD.dump`) and the files (`files-…tar.gz`) to
`/opt/collarbell/backups` every night at 02:00 UTC and deletes copies older than 14 days. They are on the same
server: they protect from mistakes, not from losing the server (copies elsewhere: later).

Restore the database from a copy:

```bash
cbc stop api
cbc exec -T postgres pg_restore --clean --if-exists -U collarbell -d collarbell < /opt/collarbell/backups/db-2026-10-06.dump
cbc start api
```

## One-time setup (done 2026-10-05)

1. `/opt/collarbell` with `.env`, `backups/`, `.ssh/`.
2. A read-only deploy key of the server for the repository (`.ssh/github`, GitHub → Settings → Deploy keys), and
   the clone: `git clone -c core.sshCommand="ssh -i /opt/collarbell/.ssh/github -o IdentitiesOnly=yes -o UserKnownHostsFile=/opt/collarbell/.ssh/known_hosts" git@github.com:larichevns/collarbell.git src`.
3. `install -m 700 src/deploy/deploy.sh /opt/collarbell/deploy`, then the first deploy by hand.
4. nginx: first only the port 80 part of `host-nginx.conf` (for the certificate), `nginx -t`, reload; then
   `certbot certonly --webroot -w /var/www/html -d <address> --account <the account of the other sites> --deploy-hook "systemctl reload nginx"`;
   then the whole `host-nginx.conf`, `nginx -t`, reload.
   A later change of `host-nginx.conf` (2026-10-06: WebSockets on `/hubs/`) goes the same way: a copy of the old file
   outside `sites-enabled/`, the new one in place, `nginx -t`, reload, and the old one back if the test fails.
5. The GitHub Actions key: `restrict,command="/opt/collarbell/deploy" ssh-ed25519 …` in root's
   `authorized_keys`; its private half in the repository's secret `DEPLOY_SSH_KEY`, the server's host keys in
   `DEPLOY_KNOWN_HOSTS`, the address in the variable `DEPLOY_HOST`.

## Moving to a real domain

1. DNS: an A record of the domain to the server.
2. nginx: `server_name` in the site file, a certificate for the new name (step 4 above).
3. `PUBLIC_URL` in `.env` (file links are signed for it), `cbc up -d api`.
4. The app: a new build with `CB_API_BASE_URL=https://<domain>` (`mobile/tool/install_phone.sh <address>`), and the
   address in `landing/src/site.ts`.
