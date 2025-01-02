ARG PHP_VERSION=8.4
ARG COMPOSER_VERSION=2.8
ARG BUN_VERSION="latest"
ARG APP_ENV

FROM composer:${COMPOSER_VERSION} AS vendor

FROM php:${PHP_VERSION}-cli-alpine AS base

LABEL maintainer="SMortexa <seyed.me720@gmail.com>"
LABEL org.opencontainers.image.title="Laravel Octane Dockerfile"
LABEL org.opencontainers.image.description="Production-ready Dockerfile for Laravel Octane"
LABEL org.opencontainers.image.source=https://github.com/exaco/laravel-octane-dockerfile
LABEL org.opencontainers.image.licenses=MIT

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC
ARG APP_ENV

ENV TERM=xterm-color \
    WITH_HORIZON=false \
    WITH_SCHEDULER=false \
    OCTANE_SERVER=swoole \
    TZ=${TZ} \
    USER=octane \
    APP_ENV=${APP_ENV} \
    ROOT=/var/www/html \
    COMPOSER_FUND=0 \
    COMPOSER_MAX_PARALLEL_HTTP=24

WORKDIR ${ROOT}

SHELL ["/bin/sh", "-eou", "pipefail", "-c"]

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
  && echo ${TZ} > /etc/timezone

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apk update; \
    apk upgrade; \
    apk add --no-cache \
    curl \
    wget \
    vim \
    git \
    ncdu \
    procps \
    ca-certificates \
    supervisor \
    libsodium-dev \
    brotli \
    # Install PHP extensions
    && install-php-extensions \
    bz2 \
    pcntl \
    mbstring \
    bcmath \
    sockets \
    pgsql \
    pdo_pgsql \
    opcache \
    exif \
    pdo_mysql \
    zip \
    uv \
    intl \
    gd \
    redis \
    rdkafka \
    memcached \
    igbinary \
    ldap \
    swoole \
    && docker-php-source delete \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

RUN arch="$(apk --print-arch)" \
    && case "$arch" in \
    armhf) _cronic_fname='supercronic-linux-arm' ;; \
    aarch64) _cronic_fname='supercronic-linux-arm64' ;; \
    x86_64) _cronic_fname='supercronic-linux-amd64' ;; \
    x86) _cronic_fname='supercronic-linux-386' ;; \
    *) echo >&2 "error: unsupported architecture: $arch"; exit 1 ;; \
    esac \
    && wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/${_cronic_fname}" \
    -O /usr/bin/supercronic \
    && chmod +x /usr/bin/supercronic \
    && mkdir -p /etc/supercronic \
    && echo "*/1 * * * * php ${ROOT}/artisan schedule:run --no-interaction" > /etc/supercronic/laravel

RUN addgroup -g ${WWWGROUP} ${USER} \
    && adduser -D -h ${ROOT} -G ${USER} -u ${WWWUSER} -s /bin/sh ${USER}

RUN mkdir -p /var/log/supervisor /var/run/supervisor \
    && chown -R ${USER}:${USER} ${ROOT} /var/log /var/run \
    && chmod -R a+rw ${ROOT} /var/log /var/run

RUN cp ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini

USER ${USER}

COPY --link --chown=${WWWUSER}:${WWWUSER} --from=vendor /usr/bin/composer /usr/bin/composer

COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/supervisord.conf /etc/supervisor/
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/octane/Swoole/supervisord.swoole.conf /etc/supervisor/conf.d/
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/supervisord.*.conf /etc/supervisor/conf.d/
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/php.ini ${PHP_INI_DIR}/conf.d/99-octane.ini
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/start-container /usr/local/bin/start-container
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/healthcheck /usr/local/bin/healthcheck

RUN chmod +x /usr/local/bin/start-container /usr/local/bin/healthcheck

###########################################

FROM base AS common

USER ${USER}

COPY --link --chown=${WWWUSER}:${WWWUSER} composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-autoloader \
    --no-ansi \
    --no-scripts \
    --audit

###########################################
# Build frontend assets with Bun
###########################################

FROM oven/bun:${BUN_VERSION} AS build

ARG APP_ENV

ENV ROOT=/var/www/html \
    APP_ENV=${APP_ENV} \
    NODE_ENV=${APP_ENV:-production}

WORKDIR ${ROOT}

COPY --link package.json bun.lock* ./

RUN bun install --frozen-lockfile

COPY --link . .
COPY --link --from=common ${ROOT}/vendor vendor

RUN bun run build

###########################################

FROM common AS runner

USER ${USER}

ENV WITH_HORIZON=false \
    WITH_SCHEDULER=false \
    WITH_REVERB=false

COPY --link --chown=${WWWUSER}:${WWWUSER} . .
COPY --link --chown=${WWWUSER}:${WWWUSER} --from=build ${ROOT}/public public

RUN mkdir -p \
    storage/framework/sessions \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/testing \
    storage/logs \
    bootstrap/cache && chmod -R a+rw storage

RUN composer install \
    --classmap-authoritative \
    --no-interaction \
    --no-ansi \
    --no-dev \
    && composer clear-cache

EXPOSE 8000
EXPOSE 8080

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD healthcheck || exit 1