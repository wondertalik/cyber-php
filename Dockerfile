

FROM alpine:latest as cyberphp56

label maintainer="Vitalii Koretskyi <tolik.developer@gmail.com>"

ARG PHP_VERSION="5.6.13"

# copy files for building php with cyber library
ADD ./sources/iprivpg.tar /app
ADD ./sources/php-${PHP_VERSION}.tar.bz2 /app

#apk add autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c
#apk add libxml2-dev libressl-dev aspell-dev bzip2-dev curl-dev sqlite-dev \
#libjpeg-turbo-dev libpng-dev libxpm-dev freetype-dev gettext-dev gmp-dev mysql-dev recode-dev

ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev dpkg \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c \
		libxml2-dev \
		libressl-dev \
		aspell-dev \
		bzip2-dev \
		curl-dev \
		sqlite-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libxpm-dev \
		freetype-dev \
		gettext-dev \
		gmp-dev \
		mysql-dev \
		recode-dev \
		libmcrypt-dev \
		libxslt-dev \
		bash

# persistent / runtime deps
RUN apk add --no-cache --virtual .persistent-deps \
		ca-certificates \
		curl \
		tar \
		xz
# https://github.com/docker-library/php/issues/494
		#openssl

# ensure www-data user exists
RUN set -x \
	&& addgroup -g 82 -S www-data \
	&& adduser -u 82 -D -S -G www-data www-data
# 82 is the standard uid/gid for "www-data" in Alpine
# http://git.alpinelinux.org/cgit/aports/tree/main/apache2/apache2.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/lighttpd/lighttpd.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/nginx-initscripts/nginx-initscripts.pre-install?h=v3.3.2


RUN set -xe \
	&& apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		coreutils \
		curl-dev

WORKDIR /app/php-${PHP_VERSION}

RUN mkdir -p /usr/local/lib/php/conf.d && mkdir -p /usr/local/lib/php/etc/php-fpm.d && \
#Init config file scan
echo 'export PHP_INI_SCAN_DIR=/usr/local/lib/php/conf.d' >> /etc/environment && source /etc/environment && \
cp -v ./php.ini-production /usr/local/lib/php.ini && \
#Compile php library
./configure --with-config-file-path=/usr/local/lib --with-config-file-scan-dir=/usr/local/lib/php/conf.d --enable-soap=shared,/usr --enable-mbstring=shared,/usr --enable-fpm --enable-zip \
--enable-bcmath --enable-pcntl --enable-ftp --enable-exif --enable-calendar --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-wddx --with-curl=shared,/usr --with-mcrypt=shared,/usr \
--with-iconv --with-gmp=shared,/usr --with-pspell=shared,/usr --with-gd=shared --with-jpeg-dir=shared,/usr --with-png-dir=shared,/usr --with-zlib-dir=shared,/usr --with-xpm-dir=shared,/usr --with-freetype-dir=shared,/usr \
--enable-gd-native-ttf --enable-gd-jis-conv --with-openssl --with-gettext=shared,/usr --with-zlib=shared,/usr --with-bz2=shared,/usr --with-recode=/usr --with-xsl=shared,/usr --with-pdo-mysql && \
make && make install

#compile cyber
WORKDIR /app/iprivpg/src
RUN chmod +x ./configure.sh && chmod +x ./utils/chk_openssl.sh && \
./configure.sh && make -f Makefile.linux && make LIBS="-lcrypto" -f Makefile.linux tests

WORKDIR /app/iprivpg/src/php/phpipriv/phpipriv
RUN phpize && ./configure --enable-ipriv --with-php-config=/usr/local/bin/php-config && make && make test && make install && \
echo 'extension=ipriv.so' > /usr/local/lib/php/conf.d/ipriv.ini && \
echo 'extension=soap.so' > /usr/local/lib/php/conf.d/soap.ini && \
echo 'extension=bz2.so' > /usr/local/lib/php/conf.d/bz2.ini && \
echo 'extension=gmp.so' > /usr/local/lib/php/conf.d/gmp.ini && \
echo 'extension=mcrypt.so' > /usr/local/lib/php/conf.d/mcrypt.ini && \
echo 'extension=zlib.so' > /usr/local/lib/php/conf.d/zlib.ini && \
echo 'extension=pspell.so' > /usr/local/lib/php/conf.d/pspell.ini && \
echo 'extension=gd.so' > /usr/local/lib/php/conf.d/gd.ini && \
echo 'extension=curl.so' > /usr/local/lib/php/conf.d/curl.ini && \
echo 'extension=gettext.so' > /usr/local/lib/php/conf.d/gettext.ini && \
echo 'extension=xsl.so' > /usr/local/lib/php/conf.d/xsl.ini && \
echo 'extension=mbstring.so' > /usr/local/lib/php/conf.d/mbstring.ini && \
echo 'zend_extension=opcache.so' > /usr/local/lib/php/conf.d/opcache.ini

WORKDIR /root

