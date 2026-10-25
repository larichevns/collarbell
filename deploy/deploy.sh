#!/bin/bash
# Deploys one commit of main on the server. Installed as /opt/collarbell/deploy: the only command the GitHub Actions
# key may run (root's authorized_keys: restrict,command="/opt/collarbell/deploy"). The commit comes as the SSH
# command (ssh root@server <sha>) or, run by hand, as the first argument.
set -euo pipefail
ROOT=/opt/collarbell

sha="${SSH_ORIGINAL_COMMAND:-${1:-}}"
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Usage: deploy <full commit sha on main>" >&2
  exit 2
fi

# One deploy at a time; the next one waits up to 15 minutes.
exec 9>"$ROOT/deploy.lock"
if ! flock -w 900 9; then
  echo "Another deploy is still running." >&2
  exit 1
fi

cd "$ROOT/src"
git fetch --quiet origin main
if ! git merge-base --is-ancestor "$sha" origin/main; then
  echo "$sha is not on main." >&2
  exit 1
fi

# CI runs can finish out of order: never go back from a newer commit that already runs.
deployed=$(cat "$ROOT/deployed" 2>/dev/null || true)
if [[ -n "$deployed" && "$deployed" != "$sha" ]] && git merge-base --is-ancestor "$sha" "$deployed" 2>/dev/null; then
  echo "A newer commit already runs: $deployed."
  exit 0
fi

git checkout --quiet --force --detach "$sha"
{
  echo "== $(date -Is) deploy $sha"
  bash deploy/release.sh
} 2>&1 | tee -a "$ROOT/deploy.log"

echo "$sha" > "$ROOT/deployed"
# This script comes from the repository too: the next deploy runs the new version. A new file, not an
# overwrite, since bash is still reading this one.
if bash -n deploy/deploy.sh; then
  install -m 700 deploy/deploy.sh "$ROOT/deploy.new"
  mv "$ROOT/deploy.new" "$ROOT/deploy"
fi
echo "== $(date -Is) deployed $sha" | tee -a "$ROOT/deploy.log"
