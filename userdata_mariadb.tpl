#!/bin/bash
# AUTOMATIC MariaDB INSTALLER IN AWS Ubuntu Server 20.04 LTS (HVM)

exec > /home/ubuntu/init.log
exec 2>&1

# Update the System
apt update  -y
apt upgrade -y

# Install MariaDB
apt install -y mariadb-server

# allow remote connections
echo "[mysqld]" | sudo tee -a /etc/mysql/my.cnf
echo "bind-address = 0.0.0.0" | sudo tee -a /etc/mysql/my.cnf

# restart mariadb
systemctl restart mariadb

# Create WordPress Database
sudo mysql << EOF
create database ${db_name};
grant all privileges on ${db_name}.* to ${username}@'%' identified by '${password}';
EOF

