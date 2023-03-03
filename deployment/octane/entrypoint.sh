#!/usr/bin/env bash
set -e

container_mode=${CONTAINER_MODE:-app}
octane_server=${OCTANE_SERVER:-swoole}
echo "Container mode: $container_mode"

php() {
  su octane -c "php $*"
}

initialStuff() {
    php artisan optimize:clear; \
    php artisan package:discover --ansi; \
    php artisan event:cache; \
    php artisan config:cache; \
    php artisan route:cache;
}

if [ "$1" != "" ]; then
    exec "$@"
elif [ ${container_mode} = "app" ]; then
    echo "Octane server: $octane_server"
    initialStuff
    if [ ${octane_server}  = "swoole" ]; then
        exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.app.conf
    elif [ ${octane_server}  = "roadrunner" ]; then
        exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.app.roadrunner.conf
    else
        echo "Invalid Octane server supplied."
        exit 1
    fi
elif [ ${container_mode} = "horizon" ]; then
    initialStuff
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.horizon.conf
elif [ ${container_mode} = "scheduler" ]; then
    initialStuff
    exec supercronic /etc/supercronic/laravel
else
    echo "Container mode mismatched."
    exit 1
fi
