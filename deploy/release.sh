#!/bin/bash
# Builds the commit checked out in /opt/collarbell/src and swaps it in; run by /opt/collarbell/deploy (deploy.sh).
# 1. The new images are built while the old containers keep running; the old images stay as :previous.
# 2. The new API brings the database and the bucket up to date ("migrate"). If that fails, nothing is replaced.
# 3. The new containers start. If /health doesn't answer within two minutes, the previous images start again.
set -euo pipefail
cd "$(dirname "$0")"

IMAGES=(collarbell-api collarbell-web)
compose() { docker compose --env-file /opt/collarbell/.env "$@"; }

# Puts the images of the running version back under :current.
restore_previous() {
  for image in "${IMAGES[@]}"; do
    if docker image inspect "$image:previous" >/dev/null 2>&1; then
      docker tag "$image:previous" "$image:current"
    fi
  done
}

healthy() {
  for _ in $(seq 60); do
    if curl -fsS --max-time 3 http://127.0.0.1:5180/health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

for image in "${IMAGES[@]}"; do
  if docker image inspect "$image:current" >/dev/null 2>&1; then
    docker tag "$image:current" "$image:previous"
  fi
done

echo "== build (--pull: base images bring .NET and nginx security fixes)"
if ! compose build --pull; then
  restore_previous
  exit 1
fi

echo "== migrate"
if ! compose run --rm api migrate; then
  echo "The database update failed: the running version stays." >&2
  restore_previous
  exit 1
fi

echo "== start"
compose up -d --remove-orphans
if ! healthy; then
  echo "The new version doesn't answer /health: starting the previous one." >&2
  compose logs --tail 100 api >&2 || true
  restore_previous
  compose up -d
  exit 1
fi
echo "== healthy"

# Untagged images of earlier versions, built by this project only.
docker image prune -f --filter label=collarbell.image >/dev/null
