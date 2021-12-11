#!/usr/bin/env bash
set -e

initialStuff() {
    php artisan event:cache; \
    php artisan optimize:clear; \
    php artisan package:discover --ansi;
}

if [ "$1" != "" ]; then
    exec "$@"
else
    initialStuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

