#!/usr/bin/env bash

# some parts/ideas in this script taken from a script by Michael Wiesing
# (https://github.com/michaelwiesing/Owncloud-Auto-Setup-for-Raspberry-Pi-2)

# Hostname
computername=$(hostname -s)

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
ocDataDir="/nas/owncloud-server/"  # where the user files are kept
logTimeZone="America/Edmonton"  # the time zone - defaults to UTC, which is bad
logFile="/var/log/owncloud.log"  # path where owncloud log should be saved

# move the 'mariadb' data directory off the SSD
sudo systemctl stop mariadb  # stop 'mariadb' to make configuration changes
print_result "${?}" "Stopped 'mariadb'"
if [[ -d /nas/mysql ]]; then  # if '/nas/mysql' exists
  print_result "${?}" "'/nas/mysql' already exists"  # say so
else
  sudo mkdir /nas/mysql  # otherwise, create it
  print_result "${?}" "'/nas/mysql' created"
  sudo chown mysql:mysql /nas/mysql  # change ownership of the new data directory
  print_result "${?}" "Chanaged ownership of '/nas/mysql'"
fi
if [[ "$(ls -A /var/lib/mysql)" ]]; then  # check for files/directories in '/var/lib/mysql'
  print_warn "'/var/lib/mysql' has files/directories in it"
  printf "\n"
  if [[ "$(ls -A /nas/mysql)" ]]; then  # there were some, so check for files/directories in '/nas/mysql'
    print_warn "'/nas/mysql' has files/directories in it"
    printf "\n"
    sudo diff -q /var/lib/mysql /nas/mysql >/dev/null  # there were some, so compare the directories
    if [[ "${?}" == 0 ]]; then  # if the directories are identical
      print_result "${?}" "The directories are identical"
    else
      print_warn "The directories are different"
      printf "\n"
      sudo cp -a /var/lib/mysql /var/lib/mysql.orig  # back up '/var/lib/mysql' for later comparison
      print_result "${?}" "Backed up '/var/lib/mysql for later comparison"
    fi
    sudo rm -rf /var/lib/mysql/*  # delete the files/directories in '/var/lib/mysql'
    print_result "${?}" "Deleted the files/directories in '/var/lib/mysql"
  else
    sudo mv /var/lib/mysql/* /nas/mysql  # move 'mariadb' data files to their new location off the SSD
    print_result "${?}" "Moved 'mariadb' data files to '/nas/mysql"
  fi
fi
sudo mount --bind /nas/mysql /var/lib/mysql  # mount the new 'mariadb' data directory location to the old one
print_result "${?}" "Mounted '/nas/mysql' -> '/var/lib/mysql'"

# configure PHP for Apache
sudo sed -E \
  -e 's,(^memory_limit = ).*,\1512M,' \
  -e 's,(^upload_max_filesize = ).*,\1500M,' \
  -e 's,(^post_max_size = ).*,\1600M,' \
  -e 's,(^max_execution_time = ).*,\1300,' \
  -e 's,^;(date.timezone =).*,\1 America/Edmonton,' \
  -e 's,^;(date.default_latitude = ).*,\153.6316,' \
  -e 's,^;(date.default_longitude = ).*,\1-113.3239,' \
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
sudo systemctl start mariadb  # changes to the config are done, so start 'mariadb' again
print_result "${?}" "'mariadb' restarted"

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

# create the Apache 'owncloud.conf' file if necessary
if [[ -e /etc/apache2/sites-available/owncloud.conf ]]; then
  print_result "${?}" "'owncloud.conf' already exists"
else
  cat <<'APACHE_OWNCLOUD_CONF' | sudo tee /etc/apache2/sites-available/owncloud.conf >/dev/null
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
  print_result "${?}" "'owncloud.conf' created"
fi

# create the ownCloud data directory, if necessary
if [[ -d "${ocDataDir}" ]]; then
  print_result "${?}" "'${ocDataDir}' already exists"
else
  sudo mkdir "${ocDataDir}"
  print_result "${?}" "'${ocDataDir}' created"
  sudo chown ${htuser}:${htgroup} ${ocDataDir}
  print_result "${?}" "'${ocDataDir}' ownership changed"
fi

# ownCloud configuration (see: https://doc.owncloud.com/server/10.11/admin_manual/configuration/server/occ_command.html#command-description)
sudo -u ${htuser} "${ocDir}"/occ maintenance:install \
  --database "mysql" \
  --database-name "${ocDb}" \
  --database-user "${ocDbUser}" \
  --database-pass "${ocDbUserPw}" \
  --admin-user "${ocAdminUser}" \
  --admin-pass "${ocAdminUserPw}" \
  --data-dir "${ocDataDir}" >/dev/null
print_result "${?}" "Configured ownCloud"

# configure ownCloud's trusted domains, if necessary
if [[ "$(sudo grep -iq "${computername}" /var/www/owncloud/config/config.php)" == 0 ]]; then
  print_result "${?}" "'${computername}' is already in the ownCloud trusted domains list"
else
  readarray -t trusteddomains < <(sudo -u ${htuser} "${ocDir}"/occ config:system:get trusted_domains)  # get a list of the current trusted domains
  numberdomains=${#trusteddomains[@]}  # get the number of domains already trusted
  sudo -u "${htuser}" "${ocDir}"/occ config:system:set trusted_domains "${numberdomains}" --value="${computername}" >/dev/null  # add this computer to the list
  print_result "${?}" "'${computername}' has been added to the ownCloud trusted domains list"
fi

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

sudo a2enmod rewrite headers env dir mime unique_id >/dev/null  # enable Apache modules needed for ownCloud
print_result "${?}" "Enabled modules for Apache"
sudo a2ensite owncloud >/dev/null  # enable the ownCloud site
print_result "${?}" "enabled the ownCloud site"
sudo systemctl restart apache2  # restart Apache
print_result "${?}" "Restarted Apache"
sudo systemctl status apache2  # show Apache's status
print_result "${?}" "Checked Apache's status"
sudo systemctl is-enabled mariadb >/dev/null # check to see if Mariadb is enabled
print_result "${?}" "Checked to make sure Mariadb is enabled"
sudo systemctl status mariadb  # show Mariadb's status
print_result "${?}" "Checked Mariadb's status"
