#!/bin/bash

php_config_file="/etc/php5/apache2/php.ini"
xdebug_config_file="/etc/php5/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"


# Update the server
apt-get update
apt-get -y upgrade

if [[ -e /var/lock/vagrant-provision ]]; then
    exit;
fi

################################################################################
# Everything below this line should only need to be done once
# To re-run full provisioning, delete /var/lock/vagrant-provision and run
#
#    $ vagrant provision
#
# From the host machine
################################################################################

IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
sed -i "s/^${IPADDR}.*//" /etc/hosts
echo $IPADDR ubuntu.localhost >> /etc/hosts			# Just to quiet down some error messages

# Install basic tools
apt-get -y install git

# Install Apache
apt-get -y install apache2
apt-get -y install php5 php5-curl php5-mysql php5-sqlite php5-xdebug

sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file}
sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file}

cat << EOF > ${xdebug_config_file}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=192.168.56.115
EOF

# Install MySQL
echo "mysql-server mysql-server/root_password password root" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password root" | sudo debconf-set-selections
apt-get -y install mysql-client mysql-server

sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${mysql_config_file}

# Allow root access from any host
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION" | mysql -u root --password=root
echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=root

# Install Z-Ray
wget http://downloads.zend.com/zray/2010/zray-php-101832-php5.5.27-linux-debian7-amd64.tar.gz
tar xvfz zray-php-101832-php5.5.27-linux-debian7-amd64.tar.gz -C /opt
mv /opt/zray-php-101832-php5.5.27-linux-debian7-amd64/zray /opt/zray
cp /opt/zray/zray-ui.conf /etc/apache2/sites-available
a2ensite zray-ui.conf
a2enmod rewrite

ln -sf /opt/zray/zray.ini /etc/php5/apache2/conf.d/zray.ini
ln -sf /opt/zray/zray.ini /etc/php5/cli/conf.d/zray.ini
ln -sf /opt/zray/lib/zray.so /usr/lib/php5/20121212/zray.so # Ubuntu 14.04
chown -R www-data:www-data /opt/zray
chmod -R 777 /opt/zray

# Install phpmyadmin
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/app-password-confirm password root' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password root' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/app-pass password root' | debconf-set-selections
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections
apt-get install -q -y phpmyadmin

# Restart Services
service apache2 restart
service mysql restart

# Cleanup the default HTML file created by Apache
rm -r /var/www/html

# Create a symbolic link to htdocs folder host
ln -s /vagrant/htdocs /var/www/html

# Lock provision
touch /var/lock/vagrant-provision
