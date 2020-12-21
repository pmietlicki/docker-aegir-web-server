FROM ubuntu:20.04

RUN apt-get update -qq\
 && apt-get install -y apt-transport-https ca-certificates \
 && apt-get install -y language-pack-fr-base software-properties-common apt-utils

RUN locale-gen fr_FR.UTF-8
ENV LANG fr_FR.UTF-8
ENV LANGUAGE fr_FR:fr

RUN apt-add-repository ppa:ondrej/php

RUN apt-get update -qq && apt-get install -y -qq\
  apache2 \
  apache2-utils \
  libapache2-mod-fcgid \
  openssl \
  php7.3 \
  php7.3-cli \
  php7.3-common \
  php7.3-gd \
  php7.3-mysql \
  php7.3-xml \
  php7.3-mbstring \
  php7.3-redis \
  php7.3-fpm \
  php-pear \
  php7.3-curl \
  sudo \
  rsync \
  sendmail \
  git-core \
  unzip \
  wget \
  curl \
  mysql-client

ENV AEGIR_UID 1000

RUN echo "Creating user aegir with UID $AEGIR_UID and GID $AEGIR_GID"

RUN addgroup --gid $AEGIR_UID aegir
RUN adduser --uid $AEGIR_UID --gid $AEGIR_UID --system --home /var/aegir aegir
RUN adduser aegir www-data
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod actions fcgid alias proxy_fcgi
RUN ln -s /var/aegir/config/apache.conf /etc/apache2/conf-available/aegir.conf
RUN ln -s /etc/apache2/conf-available/aegir.conf /etc/apache2/conf-enabled/aegir.conf

COPY sudoers-aegir /etc/sudoers.d/aegir
RUN chmod 0440 /etc/sudoers.d/aegir


# Install Composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
  composer global require drush/drush && \
  composer global require cweagans/composer-patches

# Et on fini par l'install de VIM car on en aura forcement besoin 
RUN apt-get install -y vim 

ENV DRUSH_VERSION=8.3.0
RUN wget https://github.com/drush-ops/drush/releases/download/$DRUSH_VERSION/drush.phar -O - -q > /usr/local/bin/drush
RUN chmod +x /usr/local/bin/composer
RUN chmod +x /usr/local/bin/drush

# Install fix-permissions and fix-ownership scripts
RUN wget http://cgit.drupalcode.org/hosting_tasks_extra/plain/fix_permissions/scripts/standalone-install-fix-permissions-ownership.sh
RUN bash standalone-install-fix-permissions-ownership.sh

# Prepare Aegir Logs folder.
RUN mkdir /var/log/aegir
RUN chown aegir:aegir /var/log/aegir
RUN echo 'Hello, Aegir.' > /var/log/aegir/system.log

ENV REGISTRY_REBUILD_VERSION 7.x-2.5
RUN drush dl --destination=/usr/share/drush/commands registry_rebuild-$REGISTRY_REBUILD_VERSION -y

USER aegir

RUN mkdir /var/aegir/config
RUN mkdir /var/aegir/.drush

# You may change this environment at run time. User UID 1 is created with this email address.
ENV AEGIR_CLIENT_EMAIL aegir@aegir.local.computer
ENV AEGIR_CLIENT_NAME admin
ENV AEGIR_PROFILE hostmaster
ENV AEGIR_VERSION 7.x-3.192
ENV PROVISION_VERSION 7.x-3.x
ENV AEGIR_WORKING_COPY 0
ENV AEGIR_HTTP_SERVICE_TYPE apache
ENV APACHE_PHP_RUN_USER aegir
ENV APACHE_PHP_RUN_GROUP aegir
COPY www.conf /etc/php/7.3/fpm/pool.d/www.conf

# Must be fixed across versions so we can upgrade containers.
ENV AEGIR_HOSTMASTER_ROOT /var/aegir/hostmaster

WORKDIR /var/aegir

# The Hostname of the database server to use
ENV AEGIR_DATABASE_SERVER database

VOLUME /var/aegir
USER root
EXPOSE 80
RUN /usr/sbin/apache2ctl start