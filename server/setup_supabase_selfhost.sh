#!/usr/bin/env bash
set -euo pipefail

# Self-host Supabase using official docker-compose bundle.
# Tested workflow: Ubuntu/Debian + Docker Engine + docker compose plugin.

INSTALL_DIR=${1:-$HOME/supabase-selfhost}

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -d supabase ]; then
  git clone --depth 1 https://github.com/supabase/supabase.git
fi

cd supabase/docker

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Edit it before starting (passwords/keys)."
fi

echo "Next: edit $INSTALL_DIR/supabase/docker/.env then run:"
echo "  docker compose up -d"
