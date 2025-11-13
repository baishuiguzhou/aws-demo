#!/bin/sh
set -e

if [ -f artisan ]; then
  echo "Running database migrations..."
  php artisan migrate --force || echo "Migrations failed (continuing)"
fi

exec "$@"
