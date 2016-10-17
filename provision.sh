#!/usr/bin/env bash

# Laravel homestead original provisioning script
# https://github.com/laravel/settler

# Update Package List
apt-get update
apt-get upgrade -y

# Force Locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8

# Install ssh server
apt-get -y install openssh-server pwgen
mkdir -p /var/run/sshd
sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config
sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# PPA
apt-add-repository ppa:nginx/development -y
apt-add-repository ppa:ondrej/php -y

# Update Package Lists
apt-get update

# Basic packages
apt-get install -y sudo software-properties-common nano curl \
build-essential dos2unix gcc git git-flow libmcrypt4 libpcre3-dev apt-utils \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim zip unzip

# Create homestead user
adduser homestead
usermod -p $(echo secret | openssl passwd -1 -stdin) homestead
# Add homestead to the sudo group and www-data
usermod -aG sudo homestead
usermod -aG www-data homestead

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# PHP
apt-get install -y php-cli php-dev php-pear \
php-mysql php-pgsql php-sqlite3 \
php-apcu php-json php-curl php-gd \
php-gmp php-imap php-mcrypt php-xdebug \
php-memcached php-redis php-mbstring php-zip

# Install PHP Stuffs

apt-get install -y --force-yes php7.0-cli php7.0-dev \
php-gd php-apcu php-pear \
php-curl php7.0-mcrypt \
php-imap php-mysql php-memcached php7.0-readline php-xdebug \
php-mbstring php-xml php7.0-zip php7.0-intl php7.0-bcmath php-soap

# Nginx & PHP-FPM
apt-get install -y nginx php-fpm

# Enable mcrypt
phpenmod mcrypt

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add Composer Global Bin To Path
printf "\nPATH=\"/home/homestead/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/homestead/.profile

# Laravel Envoy
su homestead <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
EOF

# Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini

sed -i "s/.*daemonize.*/daemonize = no/" /etc/php/7.0/fpm/php-fpm.conf
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/fpm/php.ini

# Enable Remote xdebug
echo "xdebug.remote_enable = 1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_connect_back = 1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_port = 9000" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.var_display_max_depth = -1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.var_display_max_children = -1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.var_display_max_data = -1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini
echo "xdebug.max_nesting_level = 500" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini

# Not xdebug when on cli
phpdismod -s cli xdebug

# Copy fastcgi_params to Nginx because they broke it on the PPA

cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param	QUERY_STRING		\$query_string;
fastcgi_param	REQUEST_METHOD		\$request_method;
fastcgi_param	CONTENT_TYPE		\$content_type;
fastcgi_param	CONTENT_LENGTH		\$content_length;
fastcgi_param	SCRIPT_FILENAME		\$request_filename;
fastcgi_param	SCRIPT_NAME		\$fastcgi_script_name;
fastcgi_param	REQUEST_URI		\$request_uri;
fastcgi_param	DOCUMENT_URI		\$document_uri;
fastcgi_param	DOCUMENT_ROOT		\$document_root;
fastcgi_param	SERVER_PROTOCOL		\$server_protocol;
fastcgi_param	GATEWAY_INTERFACE	CGI/1.1;
fastcgi_param	SERVER_SOFTWARE		nginx/\$nginx_version;
fastcgi_param	REMOTE_ADDR		\$remote_addr;
fastcgi_param	REMOTE_PORT		\$remote_port;
fastcgi_param	SERVER_ADDR		\$server_addr;
fastcgi_param	SERVER_PORT		\$server_port;
fastcgi_param	SERVER_NAME		\$server_name;
fastcgi_param	HTTPS			\$https if_not_empty;
fastcgi_param	REDIRECT_STATUS		200;
EOF

# Set The Nginx & PHP-FPM User
sed -i '1 idaemon off;' /etc/nginx/nginx.conf
sed -i "s/user www-data;/user homestead;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

mkdir -p /run/php
touch /run/php/php7.0-fpm.sock
sed -i "s/user = www-data/user = homestead/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = homestead/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/;listen\.owner.*/listen.owner = homestead/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = homestead/" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.0/fpm/pool.d/www.conf

# Install Node
curl --silent --location https://deb.nodesource.com/setup_4.x | bash -
apt-get install -y nodejs
npm install -g grunt-cli
npm install -g gulp-cli
npm install -g bower

# Install SQLite
apt-get install -y sqlite3 libsqlite3-dev

# Memcached
apt-get install -y memcached

# Beanstalkd
apt-get install -y beanstalkd
sed -i "s/#START=yes/START=no/" /etc/default/beanstalkd

# Redis
apt-get install -y redis-server
sed -i "s/daemonize yes/daemonize no/" /etc/redis/redis.conf

# Configure default nginx site
block="server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=off;

    root /var/www/html;
    server_name localhost;

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/app-error.log error;

    error_page 404 /index.php;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi.conf;
    }

    location ~ /\.ht {
        deny all;
    }
}
"

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default

cat > /etc/nginx/sites-enabled/default
echo "$block" > "/etc/nginx/sites-enabled/default"
