#!/usr/bin/env bash

# set envs
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mysql-server mysql-server/root_password password secretpassword'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password secretpassword'

# update the box
apt-get update

# set-up sync folder for nginx before
ln -fs /synced/nginx /etc/nginx

# set-up nginx
apt-get install -y nginx-full
systemctl stop nginx.service # we don't need it right now

# copy nginx config + site config
if ! [ -L /etc/nginx/nginx.conf ]; then
	rm -rf /etc/nginx/nginx.conf
	cp /vagrant/src/nginx/nginx.conf /etc/nginx/nginx.conf
	cp /vagrant/src/nginx/mediawiki.conf /etc/nginx/mediawiki.conf
fi

# expose mediawiki later
mkdir -p /srv/http/mediawiki
ln -fs /synced/mediawiki /srv/http

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
apt-get install -y unzip					# for unzipping extensions

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

# RandomSelection
wget https://github.com/inclumedia/RandomSelection/archive/master.zip -O RandomSelection.zip
unzip RandomSelection.zip -d /srv/http/mediawiki/extensions/
mv /srv/http/mediawiki/extensions/RandomSelection-master/ /srv/http/mediawiki/extensions/RandomSelection/

# MassEditRegex
wget https://extdist.wmflabs.org/dist/extensions/MassEditRegex-REL1_27-ad743a7.tar.gz
tar -xzf MassEditRegex-REL1_27-ad743a7.tar.gz -C /srv/http/mediawiki/extensions/

# Variables
wget https://extdist.wmflabs.org/dist/extensions/Variables-REL1_27-b0e1772.tar.gz
tar -xzf Variables-REL1_27-b0e1772.tar.gz -C /srv/http/mediawiki/extensions/

# Loops
wget https://extdist.wmflabs.org/dist/extensions/Loops-REL1_27-19f9cc1.tar.gz
tar -xzf Loops-REL1_27-19f9cc1.tar.gz -C /srv/http/mediawiki/extensions/

# DynamicPageList3
wget https://github.com/Alexia/DynamicPageList/archive/master.zip -O DynamicPageList3.zip
unzip DynamicPageList3.zip -d /srv/http/mediawiki/extensions/
mv /srv/http/mediawiki/extensions/DynamicPageList-master/ /srv/http/mediawiki/extensions/DynamicPageList/

# Tabber
wget https://github.com/HydraWiki/Tabber/archive/v2.4.zip -O Tabber.zip
unzip Tabber.zip -d /srv/http/mediawiki/extensions/
mv /srv/http/mediawiki/extensions/Tabber-2.4/ /srv/http/mediawiki/extensions/Tabber/

# Arrays
wget https://extdist.wmflabs.org/dist/extensions/Arrays-REL1_27-ead7f94.tar.gz
tar -xzf Arrays-REL1_27-ead7f94.tar.gz -C /srv/http/mediawiki/extensions/

# MsUpload
wget https://extdist.wmflabs.org/dist/extensions/MsUpload-REL1_27-9415674.tar.gz
tar -xzf MsUpload-REL1_27-9415674.tar.gz -C /srv/http/mediawiki/extensions/

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