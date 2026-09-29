#!/bin/sh
set -e

PLACEHOLDER="/__BASE_PATH_PLACEHOLDER__"
# OCI Hosted Deployments auto-inject the reserved APPLICATION_BASE_URL (the full
# /.../actions/invoke path). Fall back to BASE_PATH for the Container Instance deploy.
PREFIX="${APPLICATION_BASE_URL:-${BASE_PATH:-}}"
PREFIX="${PREFIX%/}"
ESCAPED=$(printf '%s' "$PREFIX" | sed 's/[\/&|]/\\&/g')

# OCI Hosted Deployments mounts the container filesystem as read-only
# except /tmp. Copy the app to /tmp so we can sed the placeholder.  A local/VM
# `npm run build` keeps server.js in .next/standalone; the image copies that
# directory's contents to /app. Support both layouts so production startup
# always performs the replacement.
SOURCE_DIR="${APP_SOURCE_DIR:-/app}"
if [ ! -f "$SOURCE_DIR/server.js" ] && [ ! -f "$SOURCE_DIR/.next/standalone/server.js" ]; then
  SOURCE_DIR="."
fi
# SOURCE_DIR may be "." on a VM. Resolve it before changing to /tmp/app so
# the next-cli fallback can still reach the checkout's node_modules.
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)

echo "[entrypoint] Staging app in /tmp/app (OCI fs is read-only outside /tmp)..."
mkdir -p /tmp/app
if [ -f "$SOURCE_DIR/server.js" ]; then
  LAYOUT="image"
  cp -r "$SOURCE_DIR"/. /tmp/app/
elif [ -f "$SOURCE_DIR/.next/standalone/server.js" ]; then
  LAYOUT="standalone"
  # Do not copy the checkout (notably node_modules) on a VM. The standalone
  # directory already contains the server and its traced runtime dependencies.
  cp -r "$SOURCE_DIR/.next" /tmp/app/.next
  cp -r "$SOURCE_DIR/public" /tmp/app/public
elif [ -x "$SOURCE_DIR/node_modules/.bin/next" ]; then
  # Some Next builds do not emit standalone output. Keep this VM fallback
  # functional by using the installed Next CLI against the staged build.
  LAYOUT="next-cli"
  cp -r "$SOURCE_DIR/.next" /tmp/app/.next
  cp -r "$SOURCE_DIR/public" /tmp/app/public
else
  echo "[entrypoint] No standalone server or installed Next.js CLI found. Run npm install && npm run build first." >&2
  exit 1
fi
cd /tmp/app

echo "[entrypoint] Replacing ${PLACEHOLDER} with '${PREFIX}' in built assets..."
if [ -f ./server.js ]; then
  find ./server.js ./.next ./public -type f \
    \( -name "*.js" -o -name "*.html" -o -name "*.json" -o -name "*.rsc" -o -name "*.css" \) \
    -exec sed -i "s|${PLACEHOLDER}|${ESCAPED}|g" {} +
else
  find ./.next ./public -type f \
    \( -name "*.js" -o -name "*.html" -o -name "*.json" -o -name "*.rsc" -o -name "*.css" \) \
    -exec sed -i "s|${PLACEHOLDER}|${ESCAPED}|g" {} +
fi

if [ "$LAYOUT" = "image" ]; then
  SERVER_DIR="."
elif [ "$LAYOUT" = "standalone" ]; then
  # Make the standalone server self-contained, matching the Docker image
  # layout. Next resolves .next/static and public relative to server.js.
  SERVER_DIR="./.next/standalone"
  mkdir -p "$SERVER_DIR/.next"
  cp -r ./.next/static "$SERVER_DIR/.next/static"
  cp -r ./public "$SERVER_DIR/public"
fi

echo "[entrypoint] Done. Starting Next.js server from /tmp/app..."
if [ "$LAYOUT" = "next-cli" ]; then
  exec "$SOURCE_DIR/node_modules/.bin/next" start
fi
cd "$SERVER_DIR"
exec node server.js
