#!/bin/bash
set -e

if [ -z "${PORT:-}" ]; then
  export PORT=10000
fi

envsubst '${PORT}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force || true

php-fpm -D
nginx -g 'daemon off;'
