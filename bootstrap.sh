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

# override default nginx with our own synced nginx folder
if ! [ -L /etc/nginx ]; then
  rm -rf /etc/nginx
  ln -fs /synced/nginx /etc/nginx
fi

# expose shared wikimedia to nginx
if ! [ -L /srv/mediawiki ]; then
  rm -rf /srv/mediawiki
  ln -fs /synced/mediawiki /srv/mediawiki
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
apt-get install -y texlive					# for mathhematical inline display

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
wget "https://releases.wikimedia.org/mediawiki/1.27/mediawiki-1.27.1.tar.gz"
tar xvf "mediawiki-1.27.1.tar.gz" -C /srv/mediawiki/ --strip-components=1

# clean
rm -rf /root/junk

# bring up nginx and php5-fpm
systemctl start nginx.service
systemctl start php5-fpm.service