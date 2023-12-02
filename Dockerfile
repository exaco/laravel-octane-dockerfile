# Accepted values: 8.2 - 8.1
ARG PHP_VERSION=8.2

ARG COMPOSER_VERSION=latest

###########################################
# Build frontend assets with PNPM
###########################################

ARG NODE_VERSION=20-alpine

FROM node:${NODE_VERSION} as build

ENV ROOT=/var/www/html

WORKDIR ${ROOT}

RUN npm install -g pnpm

COPY package.json pnpm-lock.yaml* ./

RUN if [ -f ${ROOT}/pnpm-lock.yaml ]; \
  then \
  pnpm install --frozen-lockfile --no-optional --prefer-offline; \
  elif [ -f ${ROOT}/package.json ]; \
  then \
  pnpm install --no-optional --prefer-offline; \
  fi

COPY . .

RUN pnpm run build

###########################################

FROM composer:${COMPOSER_VERSION} AS vendor

FROM php:${PHP_VERSION}-cli-bookworm

LABEL maintainer="Seyed Morteza Ebadi <seyed.me720@gmail.com>"

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

# Accepted values: swoole - roadrunner
ARG OCTANE_SERVER="swoole"

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
  librsvg2-bin \
  libfreetype6-dev \
  libssl-dev \
  libwebp-dev \
  libmcrypt-dev \
  libldap2-dev \
  libonig-dev \
  libmagickwand-dev \
  libzip-dev zip unzip \
  libargon2-1 \
  libidn2-0 \
  libpcre2-8-0 \
  librdkafka-dev \
  libpcre3 \
  libxml2 \
  libxslt-dev \
  libzstd1 \
  libc-ares-dev \
  procps \
  postgresql-client \
  postgis \
  default-mysql-client \
  libbz2-dev \
  zlib1g-dev \
  libicu-dev \
  g++ \
  # Install PHP extensions
  && docker-php-ext-install \
  bz2 \
  pcntl \
  mbstring \
  bcmath \
  sockets \
  pgsql \
  pdo_pgsql \
  opcache \
  exif \
  && docker-php-ext-configure pdo_mysql && docker-php-ext-install pdo_mysql \
  && docker-php-ext-configure zip && docker-php-ext-install zip \
  && docker-php-ext-configure intl && docker-php-ext-install intl \
  && docker-php-ext-configure gd \
  --prefix=/usr \
  --with-jpeg \
  --with-webp \
  --with-freetype && docker-php-ext-install gd \
  && pecl -q install -o -f redis && docker-php-ext-enable redis \
  && pecl -q install -o -f imagick && docker-php-ext-enable imagick \
  && pecl -q install -o -f rdkafka && docker-php-ext-enable rdkafka \
  && pecl -q install -o -f memcached && docker-php-ext-enable memcached \
  && pecl -q install -o -f igbinary && docker-php-ext-enable igbinary \
  && docker-php-ext-configure ldap --with-libdir=lib/$(gcc -dumpmachine) && docker-php-ext-install ldap \
  && if [ ${OCTANE_SERVER} = "swoole" ]; then \
  printf "\n" | pecl -q install -o -f -D 'enable-openssl="yes" enable-http2="yes" enable-swoole-curl="yes" enable-mysqlnd="yes" enable-cares="yes"' swoole \
  && docker-php-ext-enable swoole; \
  fi \
  && apt-get -y autoremove \
  && apt-get clean \
  && docker-php-source delete \
  && pecl clear-cache \
  && rm -R /tmp/pear \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && rm /var/log/lastlog /var/log/faillog


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

RUN userdel --remove --force www-data \
  && groupadd --force -g ${WWWGROUP} ${NON_ROOT_USER} \
  && useradd -ms /bin/bash --no-log-init --no-user-group -g ${WWWGROUP} -u ${WWWUSER} ${NON_ROOT_USER}

RUN chown -R ${NON_ROOT_USER}:${NON_ROOT_USER} ${ROOT} /var/{log,run}

RUN chmod -R ug+rw /var/{log,run}

USER ${NON_ROOT_USER}

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} --from=vendor /usr/bin/composer /usr/bin/composer
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} composer* ./

RUN composer install \
  --no-dev \
  --no-interaction \
  --no-autoloader \
  --no-ansi \
  --no-scripts \
  --audit

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} . .
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} --from=build ${ROOT}/public public

RUN mkdir -p \
  storage/framework/{sessions,views,cache,testing} \
  storage/logs \
  bootstrap/cache

COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/octane/supervisord* /etc/supervisor/conf.d/
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/octane/php.ini /usr/local/etc/php/conf.d/99-octane.ini
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/octane/.rr.prod.yaml ./.rr.yaml
COPY --chown=${NON_ROOT_USER}:${NON_ROOT_USER} deployment/octane/start-container /usr/local/bin/start-container

RUN composer install \
  --classmap-authoritative \
  --no-interaction \
  --no-ansi \
  --no-dev \
  && composer clear-cache \
  && php artisan storage:link

RUN if [ ${OCTANE_SERVER} = "roadrunner" ]; then \
  if composer show | grep spiral/roadrunner-cli >/dev/null; then \
  ./vendor/bin/rr get-binary; else \
  echo "spiral/roadrunner-cli package is not installed. exiting..."; exit 1; \
  fi \
  fi

RUN if [ -f "rr" ]; then \
  chmod +x rr; \
  fi

RUN chmod +x /usr/local/bin/start-container

RUN cat deployment/octane/utilities.sh >> ~/.bashrc

EXPOSE 9000
EXPOSE 6001

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1
