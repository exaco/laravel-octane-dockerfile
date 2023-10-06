# Accepted values: 8.2 - 8.1
ARG PHP_VERSION=8.2

# Accepted values: swoole - roadrunner
ARG OCTANE_SERVER="swoole"

###########################################
# Build frontend assets with PNPM
###########################################

ARG NODE_VERSION=20-alpine

FROM node:${NODE_VERSION} as build

ENV ROOT=/var/www/html

WORKDIR $ROOT

RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml* ./

RUN if [ -f $ROOT/pnpm-lock.yaml ]; \
  then \
  pnpm install --frozen-lockfile --no-optional --prefer-offline; \
  elif [ -f $ROOT/package.json ]; \
  then \
  pnpm install --no-optional --prefer-offline; \
  fi

COPY . .

RUN if [ -f $ROOT/package.json ] || [ -f $ROOT/pnpm-lock.yaml ]; \
  then \
  pnpm run build; \
  fi

FROM php:${PHP_VERSION}-cli-bookworm

LABEL maintainer="Seyed Morteza Ebadi <seyed.me720@gmail.com>"

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

ARG OCTANE_SERVER
ARG COMPOSER_VERSION=latest

# Accepted values: app - horizon - scheduler
ARG CONTAINER_MODE=app

ARG APP_WITH_HORIZON=false
ARG APP_WITH_SCHEDULER=false

ENV DEBIAN_FRONTEND=noninteractive \
  TERM=xterm-color \
  CONTAINER_MODE=${CONTAINER_MODE} \
  APP_WITH_HORIZON=${APP_WITH_HORIZON} \
  APP_WITH_SCHEDULER=${APP_WITH_SCHEDULER} \
  OCTANE_SERVER=${OCTANE_SERVER} \
  NON_ROOT_USER=octane

ENV ROOT=/var/www/html
WORKDIR $ROOT

SHELL ["/bin/bash", "-eou", "pipefail", "-c"]

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
  && echo $TZ > /etc/timezone

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
  sqlite3 \
  libcurl4-openssl-dev \
  ca-certificates \
  supervisor \
  libmemcached-dev \
  libz-dev \
  libbrotli-dev \
  libpq-dev \
  libjpeg-dev \
  libpng-dev \
  libfreetype6-dev \
  libssl-dev \
  libwebp-dev \
  libmcrypt-dev \
  libonig-dev \
  libzip-dev zip unzip \
  libargon2-1 \
  libidn2-0 \
  libpcre2-8-0 \
  libpcre3 \
  libxml2 \
  libzstd1 \
  procps \
  libbz2-dev


###########################################
# bzip2
###########################################

RUN docker-php-ext-install bz2;

###########################################
# pdo_mysql
###########################################

RUN docker-php-ext-install pdo_mysql;

###########################################
# zip
###########################################

RUN docker-php-ext-configure zip && docker-php-ext-install zip;

###########################################
# mbstring
###########################################

RUN docker-php-ext-install mbstring;

###########################################
# GD
###########################################

RUN docker-php-ext-configure gd \
  --prefix=/usr \
  --with-jpeg \
  --with-webp \
  --with-freetype \
  && docker-php-ext-install gd;

###########################################
# OPcache
###########################################

ARG INSTALL_OPCACHE=true

RUN if [ ${INSTALL_OPCACHE} = true ]; then \
  docker-php-ext-install opcache; \
  fi

###########################################
# PHP Redis
###########################################

ARG INSTALL_PHPREDIS=true

RUN if [ ${INSTALL_PHPREDIS} = true ]; then \
  pecl -q install -o -f redis \
  && rm -rf /tmp/pear \
  && docker-php-ext-enable redis; \
  fi

###########################################
# PCNTL
###########################################

ARG INSTALL_PCNTL=true

RUN if [ ${INSTALL_PCNTL} = true ]; then \
  docker-php-ext-install pcntl; \
  fi

###########################################
# BCMath
###########################################

ARG INSTALL_BCMATH=true

RUN if [ ${INSTALL_BCMATH} = true ]; then \
  docker-php-ext-install bcmath; \
  fi

###########################################
# RDKAFKA
###########################################

ARG INSTALL_RDKAFKA=true

RUN if [ ${INSTALL_RDKAFKA} = true ]; then \
  apt-get install -yqq --no-install-recommends --show-progress librdkafka-dev \
  && pecl -q install -o -f rdkafka \
  && docker-php-ext-enable rdkafka; \
  fi

###########################################
# OpenSwoole/Swoole extension
###########################################

ARG SERVER=swoole

RUN if [ ${OCTANE_SERVER} = "swoole" ]; then \
  apt-get install -yqq --no-install-recommends --show-progress libc-ares-dev \
  && printf "\n" | pecl -q install -o -f -D 'enable-openssl="yes" enable-http2="yes" enable-swoole-curl="yes" enable-mysqlnd="yes" enable-cares="yes"' ${SERVER} \
  && docker-php-ext-enable ${SERVER}; \
  fi

###########################################################################
# Human Language and Character Encoding Support
###########################################################################

ARG INSTALL_INTL=true

RUN if [ ${INSTALL_INTL} = true ]; then \
  apt-get install -yqq --no-install-recommends --show-progress zlib1g-dev libicu-dev g++ \
  && docker-php-ext-configure intl \
  && docker-php-ext-install intl; \
  fi

###########################################
# Memcached
###########################################

ARG INSTALL_MEMCACHED=false

RUN if [ ${INSTALL_MEMCACHED} = true ]; then \
  pecl -q install -o -f memcached && docker-php-ext-enable memcached; \
  fi

###########################################
# MySQL Client
###########################################

ARG INSTALL_MYSQL_CLIENT=true

RUN if [ ${INSTALL_MYSQL_CLIENT} = true ]; then \
  apt-get install -yqq --no-install-recommends --show-progress default-mysql-client; \
  fi

###########################################
# pdo_pgsql
###########################################

ARG INSTALL_PDO_PGSQL=false

RUN if [ ${INSTALL_PDO_PGSQL} = true ]; then \
  docker-php-ext-install pdo_pgsql; \
  fi

###########################################
# pgsql
###########################################

ARG INSTALL_PGSQL=false

RUN if [ ${INSTALL_PGSQL} = true ]; then \
  docker-php-ext-install pgsql; \
  fi

###########################################
# pgsql client and postgis
###########################################

ARG INSTALL_PG_CLIENT=false
ARG INSTALL_POSTGIS=false

RUN if [ ${INSTALL_PG_CLIENT} = true ]; then \
  apt-get install -yqq gnupg \
  && . /etc/os-release \
  && echo "deb http://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update -yqq \
  && apt-get install -yqq --no-install-recommends --show-progress postgresql-client-12 postgis; \
  if [ ${INSTALL_POSTGIS} = true ]; then \
  apt-get install -yqq --no-install-recommends --show-progress postgis; \
  fi \
  && apt-get purge -yqq gnupg; \
  fi

###########################################
# Laravel scheduler
###########################################

RUN if [ ${CONTAINER_MODE} = 'scheduler' ] || [ ${APP_WITH_SCHEDULER} = true ]; then \
  wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.26/supercronic-linux-amd64" \
  -O /usr/bin/supercronic \
  && chmod +x /usr/bin/supercronic \
  && mkdir -p /etc/supercronic \
  && echo "*/1 * * * * php ${ROOT}/artisan schedule:run --verbose --no-interaction" > /etc/supercronic/laravel; \
  fi

###########################################

RUN apt-get clean \
  && docker-php-source delete \
  && pecl clear-cache \
  && rm -R /tmp/pear \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && rm /var/log/lastlog /var/log/faillog

RUN userdel --remove --force www-data \
  && groupadd --force -g $WWWGROUP $NON_ROOT_USER \
  && useradd -ms /bin/bash --no-log-init --no-user-group -g $WWWGROUP -u $WWWUSER $NON_ROOT_USER

RUN chown -R $NON_ROOT_USER:$NON_ROOT_USER $ROOT /var/log/

RUN chmod -R ug+rw /var/log/

USER $NON_ROOT_USER

COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER --from=composer:${COMPOSER_VERSION} /usr/bin/composer /usr/bin/composer
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER composer* ./

RUN if [ ${OCTANE_SERVER} = "roadrunner" ]; then \
  if composer show | grep spiral/roadrunner-cli >/dev/null; then \
  ./vendor/bin/rr get-binary; else \
  echo "spiral/roadrunner-cli package is not installed. exiting..."; exit 1; \
  fi \
  fi

RUN composer install \
  --no-dev \
  --no-interaction \
  --prefer-dist \
  --no-autoloader \
  --ansi \
  --no-scripts \
  --audit

COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER . .
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER --from=build ${ROOT}/public public
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER --from=vendor ${ROOT}/rr* ${ROOT}/composer.json ./

RUN mkdir -p \
  storage/framework/{sessions,views,cache} \
  storage/logs \
  bootstrap/cache

COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER deployment/octane/supervisord* /etc/supervisor/conf.d/
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER deployment/octane/php.ini /usr/local/etc/php/conf.d/99-octane.ini
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER deployment/octane/.rr.prod.yaml ./.rr.yaml
COPY --chown=$NON_ROOT_USER:$NON_ROOT_USER deployment/octane/start-container /usr/local/bin/start-container

RUN composer dump-autoload \
  --optimize-autoloader \
  --apcu \
  --no-dev \
  --no-interaction \
  && php artisan storage:link

RUN if [ -f "rr" ]; then \
  chmod +x rr; \
  fi

RUN chmod +x /usr/local/bin/start-container

RUN cat deployment/octane/utilities.sh >> ~/.bashrc

EXPOSE 9000
EXPOSE 6001

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1
