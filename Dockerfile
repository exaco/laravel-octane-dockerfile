###########################################
# PHP dependencies
###########################################

FROM composer:latest AS vendor
WORKDIR /var/www/html
COPY composer* ./
RUN composer install \
  --no-dev \
  --no-interaction \
  --prefer-dist \
  --ignore-platform-reqs \
  --optimize-autoloader \
  --apcu-autoloader \
  --ansi \
  --no-scripts

###########################################

FROM php:8.1-cli-buster

ARG WWWUSER=1000
ARG WWWGROUP=1000

ARG TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

ENV TERM=xterm-color

WORKDIR /var/www/html

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN set -eu; \
    apt-get update; \
    apt-get upgrade -yqq; \
    pecl channel-update pecl.php.net; \
    apt-get install -yqq --no-install-recommends \
          apt-utils \
          gnupg \
          gosu \
          git \
          curl \
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
          procps

RUN set -e; \
    docker-php-ext-configure zip \
            && docker-php-ext-install zip; \
    docker-php-ext-install \
            mbstring \
            pdo_mysql; \
    docker-php-ext-configure gd \
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
      pecl install -o -f redis \
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
      apt-get install -yqq librdkafka-dev \
      && pecl install rdkafka \
      && docker-php-ext-enable rdkafka; \
  fi

###########################################
# Swoole extension
###########################################

ARG INSTALL_SWOOLE=true

RUN set -eux; \
    if [ ${INSTALL_SWOOLE} = true ]; then \
      apt-get install -yqq libc-ares-dev \
      && pecl install -D 'enable-openssl="yes" enable-http2="yes" enable-swoole-curl="yes" enable-mysqlnd="yes" enable-cares="yes"' swoole \
      && docker-php-ext-enable swoole; \
    fi

###########################################################################
# Human Language and Character Encoding Support
###########################################################################

ARG INSTALL_INTL=true

RUN if [ ${INSTALL_INTL} = true ]; then \
      apt-get install -yqq zlib1g-dev libicu-dev g++ \
      && docker-php-ext-configure intl \
      && docker-php-ext-install intl; \
  fi

###########################################
# MySQL Client
###########################################

USER root

ARG INSTALL_MYSQL_CLIENT=true

RUN if [ ${INSTALL_MYSQL_CLIENT} = true ]; then \
      apt-get install -yqq default-mysql-client; \
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
      . /etc/os-release \
      && echo "deb http://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
      && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
      && apt-get install -yqq postgresql-client-12 postgis; \
      if [ ${INSTALL_POSTGIS} = true ]; then \
        apt-get install -yqq postgis; \
      fi; \
  fi

###########################################

RUN groupadd --force -g $WWWGROUP octane
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u $WWWUSER octane

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm /var/log/lastlog /var/log/faillog

COPY . .

RUN mkdir -p \
  ./storage/framework/sessions \
  ./storage/framework/views \
  ./storage/framework/cache \
  ./storage/logs \
  ./bootstrap/cache \
  && chown -R octane:octane \
  ./storage \
  ./bootstrap/cache \
  && chmod -R ug+rwx ./storage ./bootstrap/cache

COPY --from=vendor /var/www/html/vendor ./vendor

COPY ./deployment/octane/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./deployment/octane/php.ini /usr/local/etc/php/conf.d/octane.ini
COPY ./deployment/octane/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

RUN chmod +x ./deployment/octane/entrypoint.sh
RUN cat ./deployment/octane/utilities.sh >> ~/.bashrc

EXPOSE 9000

ENTRYPOINT ["./deployment/octane/entrypoint.sh"]
