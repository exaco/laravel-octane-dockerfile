FROM debian:trixie-slim

ARG COMPOSER_VERSION=latest

###########################################
# Build frontend assets with NPM
###########################################

ARG NODE_VERSION=20-alpine

FROM node:${NODE_VERSION} as build

ENV ROOT=/var/www/html

WORKDIR ${ROOT}

RUN npm config set update-notifier false && npm set progress=false

COPY package*.json ./

RUN if [ -f $ROOT/package-lock.json ]; \
    then \
    npm ci --no-optional --loglevel=error --no-audit; \
    else \
    npm install --no-optional --loglevel=error --no-audit; \
    fi

COPY . .

RUN npm run build

###########################################

LABEL maintainer="SMortexa <seyed.me720@gmail.com>"

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-color \
    WITH_HORIZON=false \
    WITH_SCHEDULER=false \
    OCTANE_SERVER=frankenphp \
    NON_ROOT_USER=octane \
    ROOT=/var/www/html

WORKDIR ${ROOT}

SHELL ["/bin/bash", "-eou", "pipefail", "-c"]

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

RUN apt-get update; \
    apt-get upgrade -yqq; \
    pecl -q channel-update pecl.php.net; \
    apt-get install -yqq --no-install-recommends --show-progress \
    apt-utils \
    gnupg \
    git \
    curl \
    wget \
    nano \
    rsync \
    ncdu \
    sqlite3 \
    ca-certificates \
    supervisor \
    libzip-dev zip unzip \
    && apt-get -y autoremove \
    && apt-get clean \
    && docker-php-source delete \
    && pecl clear-cache \
    && rm -R /tmp/pear \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm /var/log/lastlog /var/log/faillog

RUN wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64" \
    -O /usr/bin/supercronic \
    && chmod +x /usr/bin/supercronic \
    && mkdir -p /etc/supercronic \
    && echo "*/1 * * * * php ${ROOT}/artisan schedule:run --verbose --no-interaction" > /etc/supercronic/laravel

RUN userdel --remove --force www-data \
    && groupadd --force -g ${WWWGROUP} ${NON_ROOT_USER} \
    && useradd -ms /bin/bash --no-log-init --no-user-group -g ${WWWGROUP} -u ${WWWUSER} ${NON_ROOT_USER}

RUN chown -R ${NON_ROOT_USER}:${NON_ROOT_USER} ${ROOT} /var/{log,run}

RUN chmod -R ug+rw /var/{log,run}

USER ${NON_ROOT_USER}

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} --from=composer:${COMPOSER_VERSION} /usr/bin/composer /usr/bin/composer
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} composer* ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-autoloader \
    --no-ansi \
    --no-scripts \
    --audit

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} . .
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} --from=dunglas/frankenphp /usr/local/bin/frankenphp /usr/bin/frankenphp

RUN mkdir -p \
    storage/framework/{sessions,views,cache,testing} \
    storage/logs \
    bootstrap/cache

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/octane/Swoole/supervisord.swoole.conf /etc/supervisor/conf.d/
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/supervisord.scheduler.conf /etc/supervisor/conf.d/
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/supervisord.horizon.conf /etc/supervisor/conf.d/
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/start-container /usr/local/bin/start-container

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/php.ini /usr/local/etc/php/conf.d/99-octane.ini
RUN sed -i 's/variables_order = "GPCS"/variables_order = "EGPCS"/' /usr/local/etc/php/conf.d/99-octane.ini

RUN composer install \
    --classmap-authoritative \
    --no-interaction \
    --no-ansi \
    --no-dev \
    && composer clear-cache \
    && php artisan storage:link

RUN chmod +x /usr/local/bin/start-container

RUN cat deployment/utilities.sh >> ~/.bashrc

EXPOSE 80

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1