# Accepted values: 8.3 - 8.2
ARG PHP_VERSION=8.3

ARG COMPOSER_VERSION=latest

###########################################
# Build frontend assets with NPM
###########################################

ARG NODE_VERSION=20-alpine

FROM node:${NODE_VERSION} AS build

ENV ROOT=/var/www/html

WORKDIR ${ROOT}

RUN npm config set update-notifier false && npm set progress=false

COPY package*.json ./

RUN if [ -f $ROOT/package-lock.json ]; \
  then \
    npm ci --loglevel=error --no-audit; \
  else \
    npm install --loglevel=error --no-audit; \
  fi

COPY . .

RUN npm run build

###########################################

FROM composer:${COMPOSER_VERSION} AS vendor

FROM php:${PHP_VERSION}-cli-alpine

LABEL maintainer="SMortexa <seyed.me720@gmail.com>"
LABEL org.opencontainers.image.title="Laravel Octane Dockerfile"
LABEL org.opencontainers.image.description="Production-ready Dockerfile for Laravel Octane"
LABEL org.opencontainers.image.source=https://github.com/exaco/laravel-octane-dockerfile
LABEL org.opencontainers.image.licenses=MIT

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

ENV DEBIAN_FRONTEND=noninteractive \
  TERM=xterm-color \
  WITH_HORIZON=false \
  WITH_SCHEDULER=false \
  OCTANE_SERVER=roadrunner \
  USER=octane \
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
  nano \
  ncdu \
  procps \
  ca-certificates \
  supervisor \
  libsodium-dev \
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
  intl \
  gd \
  redis \
  rdkafka \
  memcached \
  igbinary \
  ldap \
  && docker-php-source delete \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64" \
  -O /usr/bin/supercronic \
  && chmod +x /usr/bin/supercronic \
  && mkdir -p /etc/supercronic \
  && echo "*/1 * * * * php ${ROOT}/artisan schedule:run --no-interaction" > /etc/supercronic/laravel

RUN addgroup -g ${WWWGROUP} ${USER} \
  && adduser -D -h ${ROOT} -G ${USER} -u ${WWWUSER} -s /bin/sh ${USER}

RUN mkdir -p /var/log/supervisor /var/run/supervisor \
  && chown -R ${USER}:${USER} /var/log/supervisor /var/run/supervisor

RUN cp ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini

USER ${USER}

COPY --chown=${USER}:${USER} --from=vendor /usr/bin/composer /usr/bin/composer
COPY --chown=${USER}:${USER} composer.json composer.lock ./

RUN composer install \
  --no-dev \
  --no-interaction \
  --no-autoloader \
  --no-ansi \
  --no-scripts \
  --audit

COPY --chown=${USER}:${USER} . .
COPY --chown=${USER}:${USER} --from=build ${ROOT}/public public

RUN mkdir -p \
  storage/framework/sessions \
  storage/framework/views \
  storage/framework/cache \
  storage/framework/testing \
  storage/logs \
  bootstrap/cache && chmod -R a+rw storage

COPY --chown=${USER}:${USER} deployment/supervisord.conf /etc/supervisor/
COPY --chown=${USER}:${USER} deployment/octane/RoadRunner/supervisord.roadrunner.conf /etc/supervisor/conf.d
COPY --chown=${USER}:${USER} deployment/supervisord.*.conf /etc/supervisor/conf.d/
COPY --chown=${USER}:${USER} deployment/php.ini ${PHP_INI_DIR}/conf.d/99-octane.ini
COPY --chown=${USER}:${USER} deployment/octane/RoadRunner/.rr.prod.yaml ./.rr.yaml
COPY --chown=${USER}:${USER} deployment/start-container /usr/local/bin/start-container

RUN composer install \
  --classmap-authoritative \
  --no-interaction \
  --no-ansi \
  --no-dev \
  && composer clear-cache \
  && php artisan storage:link

RUN if composer show | grep spiral/roadrunner-cli >/dev/null; then \
  ./vendor/bin/rr get-binary; else \
  echo "`spiral/roadrunner-cli` package is not installed. Exiting..."; exit 1; \
  fi

RUN chmod +x rr /usr/local/bin/start-container

RUN cat deployment/utilities.sh >> ~/.bashrc

EXPOSE 8000
EXPOSE 6001

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1
