#!/usr/bin/env bash

# some parts/ideas in this script taken from a script by Michael Wiesing
# (https://github.com/michaelwiesing/Owncloud-Auto-Setup-for-Raspberry-Pi-2)

# Hostname
hostname=$(hostname -s)

# Mariadb configuration
mysqlRootPw="c0c0b7d"  # password for the root user of mysql
ocDb="owncloud"  # name of the mysql database for owncloud
ocDbUser="owncloud"  # name of the mysql user for owncloud
ocDbUserPw="c0c0b7d"  # password for the mysql user for owncloud

# Apache configuration
maxFileSize="1024M"  # max size of files that can be uploaded to owncloud
htuser=$(ps -ef | egrep '(apache|apache2)' | grep -v `whoami` | grep -v root | head -n1 | awk '{print $1}')  # user Apache runs under
htgroup="${htuser}"  # group Apache runs under

# ownCloud configuration
ocAdminUser="rtruell"  # name of the owncloud administrator
ocAdminUserPw="c0c0b7d"  # password for the owncloud administrator
ocDir="/var/www/owncloud"  # where ownCloud lives
ocDataDir="/var/www/owncloud/data"  # where the user files are kept
# ocDataDir="/nas/owncloud-server/"  # where the user files are kept
logTimeZone="America/Edmonton"  # the time zone - defaults to UTC, which is bad
logFile="/var/log/owncloud.log"  # path where owncloud log should be saved

# create the ownCloud data directory, if necessary
if [[ -d "${ocDataDir}" ]]; then
  print_result "${?}" "'${ocDataDir}' already exists"
else
  sudo mkdir "${ocDataDir}"
  print_result "${?}" "'${ocDataDir}' created"
  sudo chown ${htuser}:${htgroup} ${ocDataDir}
  print_result "${?}" "'${ocDataDir}' ownership changed"
fi

# # PHP 8 repository
# sudo "${HOME}"/bin/add-apt-key https://packages.sury.org/php/apt.gpg php "deb https://packages.sury.org/php/ $(lsb_release -sc) main"
# print_result "${?}" "Added PHP 8 repository"
# ownCloud server repository
sudo "${HOME}"/bin/add-apt-key https://download.opensuse.org/repositories/isv:ownCloud:server:10/Debian_11/Release.key owncloud "deb http://download.opensuse.org/repositories/isv:/ownCloud:/server:/10/Debian_11/ /"
print_result "${?}" "Added ownCloud repository"
retcode=1
while [[ "${retcode}" != 0 ]]; do
  sudo apt update  # update 'apt' so ownCloud can be installed, and make sure the update actually happened
  retcode="${?}"
done
print_result "${retcode}" "Updated 'apt'"

# packages needed to run ownCloud
declare -a packages=(
  "apache2"
  "curl"
  "libapache2-mod-php"
  "mariadb-server"
  "php"
  "unzip"
  "php-apcu"
  "php-bcmath"
  "php-bz2"
  "php-curl"
  "php-gd"
  "php-gmp"
  "php-imagick"
  "php-intl"
  "php-mbstring"
  "php-mysql"
  "php-xml"
  "php-zip"
  "owncloud-complete-files"
)
for i in ${packages[@]}; do  # loop through the array of packages ...
  apt_package_installer "${i}"  # ... installing them if necessary
done

# configure PHP for Apache
sudo sed -E \
  -e 's,(^memory_limit = ).*,\1512M,' \
  -e 's,(^upload_max_filesize = ).*,\1500M,' \
  -e 's,(^post_max_size = ).*,\1600M,' \
  -e 's,(^max_execution_time = ).*,\1300,' \
  -e 's,^;(date.timezone =).*,\1 America/Edmonton,' \
  -e 's,(^output_buffering = ).*,\1Off,' \
  -e 's,^;(opcache.revalidate_freq=).*,\11,' \
  -e 's,^;(zend_extension=opcache.*),\1,' \
  -e 's,^;(opcache.enable=1.*),\1,' \
  -e 's,^;(opcache.interned_strings_buffer=8.*),\1,' \
  -e 's,^;(opcache.max_accelerated_files=10000.*),\1,' \
  -e 's,^;(opcache.memory_consumption=128.*),\1,' \
  -e 's,^;(opcache.save_comments=1.*),\1,' \
  -i /etc/php/7.4/apache2/php.ini
print_result "${?}" "PHP configured"

# Set database root password with `debconf-set-selections`
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${mysqlRootPw}" # password for the MySQL root user
retcode1="${?}"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${mysqlRootPw}" # repeat password for the MySQL root user
retcode2="${?}"
if [[ "${retcode1}" == 0 && "${retcode2}" == 0 ]]; then
  retcode=0
else
  retcode=1
fi
print_result "${retcode}" "Mariadb root password set"

# secure Mariadb
sudo mysql --user=root --password=${mysqlRootPw} << SECURE_MARIADB
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DELETE FROM mysql.user WHERE User='';
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
  FLUSH PRIVILEGES;
SECURE_MARIADB
print_result "${?}" "Mariadb secured"

# create the ownCloud database
sudo mysql --user=root --password=${mysqlRootPw} <<CREATE_DATABASE
  CREATE DATABASE ${ocDb};
  CREATE USER ${ocDbUser}@localhost IDENTIFIED BY '${ocDbUserPw}';
  GRANT ALL PRIVILEGES ON ${ocDb}.* TO ${ocDbUser}@localhost;
  FLUSH PRIVILEGES;
CREATE_DATABASE
print_result "${?}" "ownCloud database created"

# change Apache upload filesize in the .htaccess file
sudo sed -E \
  -e "s/php_value upload_max_filesize .*/php_value upload_max_filesize ${maxFileSize}/" \
  -e "s/php_value post_max_size .*/php_value post_max_size ${maxFileSize}/" \
  -e "s/php_value memory_limit .*/php_value memory_limit ${maxFileSize}/" \
  -i /var/www/owncloud/.htaccess
print_result "${?}" "Apache upload filesizes changed"

# create the Apache 'owncloud.conf' file
cat <<'APACHE_OWNCLOUD_CONF' |  sudo tee /etc/apache2/sites-available/owncloud.conf
Alias /owncloud "/var/www/owncloud/"

<Directory /var/www/owncloud/>
  Options +FollowSymlinks
  AllowOverride All

 <IfModule mod_dav.c>
  Dav off
 </IfModule>

 SetEnv HOME /var/www/owncloud
 SetEnv HTTP_HOME /var/www/owncloud

</Directory>
APACHE_OWNCLOUD_CONF
print_result "${?}" "'owncloud.conf' file for Apache created"

# ownCloud configuration (see: https://doc.owncloud.com/server/10.11/admin_manual/configuration/server/occ_command.html#command-line-installation)
sudo -u ${htuser} php "${ocDir}"/occ maintenance:install \
  --database "mysql" \
  --database-name "${ocDb}" \
  --database-user "${ocDbUser}" \
  --database-pass "${ocDbUserPw}" \
  --admin-user "${ocAdminUser}" \
  --admin-pass "${ocAdminUserPw}" \
  --data-dir "${ocDataDir}"
print_result "${?}" "Configured ownCloud"

# configure the owncloud logfile
logFileMasked=$(printf '%s' "${logFile}" | sed 's/\//\\\//g')
logTimezoneMasked=$(printf '%s' "${logTimeZone}" | sed 's/\//\\\//g')
sudo sed -i "s/  'logtimezone' => 'UTC',/  'logtimezone' => '${logTimezoneMasked}',\n  'logfile' => '${logFileMasked}',\n  'loglevel' => '2',/" /var/www/owncloud/config/config.php
print_result "${?}" "Configured ownCloud logfile"
sudo touch "${logFile}"
print_result "${?}" "Created ownCloud logfile"
sudo chown "${htuser}":"${htgroup}" "${logFile}"
print_result "${?}" "ownCloud logfile ownership changed"

# configure ownCloud to use apcu
sudo sed -i "s/);/  'memcache.local' => '\\\OC\\\Memcache\\\APCu',\n);/" /var/www/owncloud/config/config.php
print_result "${?}" "Configured ownCloud to use 'apcu'"

sudo a2enmod rewrite mime unique_id ssl headers  # enable Apache modules needed for ownCloud
sudo a2ensite owncloud  # enable the ownCloud website
sudo systemctl restart apache2  # restart Apache
sudo systemctl status apache2  # show Apache's status
sudo systemctl is-enabled mariadb  # check to see if Mariadb is enabled
sudo systemctl status mariadb  # show Mariadb's status
