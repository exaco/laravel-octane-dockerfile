#!/usr/bin/env bash
set -e

initialStuff() {
    php artisan event:cache; \
    php artisan config:cache; \
    php artisan route:cache;
}

if [ "$1" != "" ]; then
    exec "$@"
else
    initialStuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

