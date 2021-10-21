###########################################
# PHP dependencies
###########################################

FROM composer:latest AS vendor
WORKDIR /var/www/html/
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

FROM php:8.0-buster

ARG WWWUSER=1000
ARG WWWGROUP=1000

WORKDIR /var/www/html

ARG deployment_env="Production"
ENV deployment_env=${deployment_env}

ARG TZ=Asia/Tehran
ENV DEBIAN_FRONTEND=noninteractive

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -yqq; \
    pecl channel-update pecl.php.net && \
    apt-get install -yqq --no-install-recommends \
            apt-utils \
            gnupg \
            gosu \
            git \
            curl \
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
            libzip-dev zip unzip


RUN mkdir -p ~/.gnupg \
        && chmod 600 ~/.gnupg \
        && echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf \
        && apt-key adv --homedir ~/.gnupg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E5267A6C \
        && apt-key adv --homedir ~/.gnupg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C300EE8C \
        && echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu focal main" > /etc/apt/sources.list.d/ppa_ondrej_php.list

RUN set -xe; \
    docker-php-ext-configure zip && \
            docker-php-ext-install zip && \
            php -m | grep -q 'zip'; \
    docker-php-ext-install \
            mbstring \
            pdo_mysql; \
    docker-php-ext-configure gd \
            --prefix=/usr \
            --with-jpeg \
            --with-webp \
            --with-freetype && \
    docker-php-ext-install gd; \
    php -r 'var_dump(gd_info());'

###########################################
# Opcache
###########################################

ARG INSTALL_OPCACHE=true

RUN if [ ${INSTALL_OPCACHE} = true ]; then \
  docker-php-ext-install opcache \
  ;fi

###########################################
# PHP REDIS EXTENSION
###########################################

ARG INSTALL_PHPREDIS=true

RUN if [ ${INSTALL_PHPREDIS} = true ]; then \
  pecl install -o -f redis \
  && rm -rf /tmp/pear \
  && docker-php-ext-enable redis \
  ;fi

###########################################
# pcntl
###########################################

ARG INSTALL_PCNTL=true
RUN if [ ${INSTALL_PCNTL} = true ]; then \
  docker-php-ext-install pcntl \
  ;fi

###########################################
# bcmath:
###########################################

ARG INSTALL_BCMATH=true

RUN if [ ${INSTALL_BCMATH} = true ]; then \
  docker-php-ext-install bcmath \
  ;fi

###########################################
# RDKAFKA:
###########################################

ARG INSTALL_RDKAFKA=true

RUN if [ ${INSTALL_RDKAFKA} = true ]; then \
  apt-get install -y librdkafka-dev && \
  pecl install rdkafka && \
  docker-php-ext-enable rdkafka \
  ;fi

###########################################
# Swoole EXTENSION
###########################################

ARG INSTALL_SWOOLE=true
RUN set -eux; \
    if [ ${INSTALL_SWOOLE} = true ]; then \
      pecl install swoole; \
      docker-php-ext-enable swoole; \
      php -m | grep -q 'swoole'; \
    fi

###########################################################################
# Human Language and Character Encoding Support:
###########################################################################

ARG INSTALL_INTL=true

RUN if [ ${INSTALL_INTL} = true ]; then \
    # Install intl and requirements
    apt-get install -yqq zlib1g-dev libicu-dev g++ && \
    docker-php-ext-configure intl && \
    docker-php-ext-install intl \
;fi

###########################################
# MySQL Client:
###########################################

USER root

ARG INSTALL_MYSQL_CLIENT=true

RUN if [ ${INSTALL_MYSQL_CLIENT} = true ]; then \
  apt-get -y install default-mysql-client \
  ;fi

###########################################

RUN groupadd --force -g $WWWGROUP octane
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 octane

RUN if [ ! -z "$WWWUSER" ]; then \
    usermod -u $WWWUSER octane; \
fi

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm /var/log/lastlog /var/log/faillog

COPY . /var/www/html/

COPY --from=vendor /var/www/html/vendor /var/www/html/vendor

RUN cp ./deployment/octane/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \
    cp ./deployment/octane/php.ini /usr/local/etc/php/conf.d/99-octane.ini && \
    cp ./deployment/octane/opcache.ini /usr/local/etc/php/conf.d/opcache.ini && \
    chgrp -R octane  ./storage/logs/ ./bootstrap/cache/ && \
    chmod +x ./deployment/octane/entrypoint.sh && \
	ln -s /var/www/html/deployment/octane/entrypoint.sh /entrypoint.sh && \
	cat ./deployment/octane/utilities.sh >> ~/.bashrc

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
