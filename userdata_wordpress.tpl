#!/bin/bash
# AUTOMATIC WORDPRESS INSTALLER IN  AWS Ubuntu Server 20.04 LTS (HVM)

# varaible will be populated by terraform template
db_username=${db_username}
db_password=${db_user_password}
db_name=${db_name}
db_HOST=${db_HOST}

my_domain=${ec2_url}
web_tile=${web_title}
admin_name=${admin_username}
admin_pass=${admin_password}
admin_email=${admin_email}

ACCESS_KEY=${iam_access_key}
SECRET_KEY=${iam_secret}
bucket_name=${s3_bucket_name}
bucket_region=${s3_bucket_region}

exec > /home/ubuntu/init.log
exec 2>&1

# install LAMP Server
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
usermod -a -G www-data ubuntu
chown -R ubuntu:www-data /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

#**********************Installing Wordpress using WP CLI********************************* 
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
wp core download --path=/var/www/html --allow-root

# Connect wordpress to database
apt-get install -q -y wait-for-it
wait-for-it -t 0 "$db_HOST:3306" # wait for db connection port to establish
wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_password --dbhost=$db_HOST --path=/var/www/html --allow-root --extra-php <<PHP
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
PHP

# Change permission of /var/www/html/
chown -R ubuntu:www-data /var/www/html
chmod -R 774 /var/www/html
rm /var/www/html/index.html
#  enable .htaccess files in Apache config using sed command
sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf
a2enmod rewrite

# restart apache
systemctl restart apache2

# install core wordpress
wp core install --url=$my_domain --title=$website_title --admin_user=$admin_name \
--admin_password=$admin_pass  --admin_email=$admin_email --path=/var/www/html --allow-root

# configure wp media offload plugin
cat <<EOT >> credfile.txt
define( 'AS3CF_SETTINGS', serialize( array (
    'provider' => 'aws',
    'access-key-id' => '$ACCESS_KEY',
    'secret-access-key' => '$SECRET_KEY',
    'bucket' => '$bucket_name',
    'region' => '$bucket_region',
    'copy-to-s3' => true,
    'serve-from-s3' => true,
    'remove-local-file' => true,
) ) );
EOT

# insert the temporary file the WordPress configuration file
sed -i "/define( 'WP_DEBUG', false );/r credfile.txt" /var/www/html/wp-config.php 
# restart apache server
systemctl restart apache2 
# install wp media offload plugin
wp plugin install amazon-s3-and-cloudfront --path=/var/www/html --activate --allow-root

echo WordPress Installed


