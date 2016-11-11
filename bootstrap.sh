#!/usr/bin/env bash

# set envs
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mysql-server mysql-server/root_password password secretpassword'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password secretpassword'

# update the box
apt-get update

# set-up nginx
apt-get install -y nginx-full
systemctl stop nginx.service # we don't need it right now

# copy nginx config + site config
if ! [ -L /etc/nginx/nginx.conf ]; then
  rm -rf /etc/nginx/nginx.conf
  cp /vagrant/src/nginx/nginx.conf /etc/nginx/nginx.conf
  cp /vagrant/src/nginx/mediawiki.conf /etc/nginx/mediawiki.conf
fi

# expose "interesting" folders to share
if ! [ -L /srv/http/mediawiki ]; then
  rm -rf /srv/http/mediawiki
  ln -fs /synced/mediawiki /srv/http/mediawiki
fi

# php5 for lazy debian defaults
apt-get install -y php5-fpm
systemctl stop php5-fpm.service # we don't need it right now

# compile php5 - install dependencies for libraries and extensions
apt-get install -y build-essential # for building
apt-get build-dep -y php5 # dependencies for building

apt-get install -y php5-intl				# to handle Unicode normalization
apt-get install -y php5-apcu 				# local object caching
apt-get install -y php5-mysqlnd				# mysql php driver
apt-get install -y imagemagick 				# imagemagick for thumbnails
apt-get install -y texlive					# for mathematical inline display

# build
mkdir /root/junk
cd /root/junk
wget "http://fr2.php.net/get/php-5.6.27.tar.gz/from/this/mirror"
tar xvf mirror
cd "php-5.6.27"
./configure --prefix=/ \
	-with-zlib-dir \
	--with-freetype-dir \
	--enable-mbstring \
	--with-libxml-dir=/usr \
	--enable-soap \
	--enable-calendar \
	--with-curl \
	--with-mcrypt \
	--with-zlib \
	--with-pgsql \
	--disable-rpath \
	--enable-inline-optimization \
	--with-bz2 \
	--with-zlib \
	--enable-sockets \
	--enable-sysvsem \
	--enable-sysvshm \
	--enable-pcntl \
	--enable-mbregex \
	--enable-exif \
	--enable-bcmath \
	--with-mhash \
	--enable-zip \
	--enable-intl \
	--with-pcre-regex \
	--with-mysql \
	--with-pdo-mysql \
	--with-mysqli \
	--with-jpeg-dir=/usr \
	--with-png-dir=/usr \
	--enable-gd-native-ttf \
	--with-openssl \
	--with-fpm-user=www-data \
	--with-fpm-group=www-data \
	--with-libdir=/lib/ \
	--enable-ftp \
	--with-imap \
	--with-imap-ssl \
	--with-kerberos \
	--with-gettext \
	--with-xmlrpc \
	--with-xsl \
	--enable-opcache \
	--enable-fpm
make
make install
cd "../"

# enable APCu for php5-fpm
sed -i -e '$a\apc.enabled=1' -e '$a\apc.enable_cli=1' 20-apcu.ini

# get mediawiki
mkdir -p /srv/http/mediawiki
wget "https://releases.wikimedia.org/mediawiki/1.27/mediawiki-1.27.1.tar.gz"
tar xvf "mediawiki-1.27.1.tar.gz" -C /srv/http/mediawiki --strip-components=1

# install mediawiki extensions

# restore mediawiki backups if they exist
# LocalSettings.php
if ! [ -L "/synced/restore/LocalSettings.php" ]; then
  cp "/synced/restore/LocalSettings.php" "/srv/http/mediawiki/LocalSettings.php"
fi
# images
if ! [ -L "/synced/restore/images.tar.gz" ]; then
	tar xvf "/synced/restore/images.tar.gz" -C /srv/http/mediawiki --strip-components=4
fi
# database
if ! [ -L "/synced/restore/backup.sql" ]; then
	mysqladmin -u root -p'secretpassword' create mediawiki
	mysql -u root -p'secretpassword' mediawiki < /synced/restore/backup.sql
fi

# clean
rm -rf /root/junk

# bring up nginx and php5-fpm
systemctl start nginx.service
systemctl start php5-fpm.service