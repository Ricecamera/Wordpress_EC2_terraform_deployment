#!/bin/bash
# AUTOMATIC WORDPRESS INSTALLER IN  AWS Ubuntu Server 20.04 LTS (HVM)

# varaible will be populated by terraform template
db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_HOST=${db_HOST}

exec > /home/ubuntu/init.log
exec 2>&1

# install LAMP Server
apt update  -y
apt upgrade -y
apt update  -y
apt upgrade -y
#install apache server
apt install -y apache2
 

apt install -y php
apt install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,bcmath,json,xml,intl,zip,imap,imagick}



#and download mysql package to yum  and install mysql client from yum
apt install -y mariadb-client

# starting apache  and register them to startup

systemctl enable --now  apache2


# Change OWNER and permission of directory /var/www
sudo usermod -a -G www-data ubuntu
sudo chown -R ubuntu:www-data /var/www
sudo find /var/www -type d -exec chmod 2775 {} \;
sudo find /var/www -type f -exec chmod 0664 {} \;

#**********************Installing Wordpress using WP CLI********************************* 
sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
wp core download --path=/var/www/html --allow-root
wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_user_password --dbhost=$db_HOST --path=/var/www/html --allow-root --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

# Change permission of /var/www/html/
sudo chown -R ubuntu:www-data /var/www/html
sudo chmod -R 774 /var/www/html
sudo rm /var/www/html/index.html
#  enable .htaccess files in Apache config using sed command
sudo sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf
sudo a2enmod rewrite

# restart apache
systemctl restart apache2

echo WordPress Installed

