#!/usr/bin/env bash

# some parts/ideas in this script taken from a script by Michael Wiesing
# (https://github.com/michaelwiesing/Owncloud-Auto-Setup-for-Raspberry-Pi-2)

# hostname
computername=$(hostname -s)

# 'mariadb' configuration variables
mysqlRootPw="c0c0b7d"  # password for the root user of 'mariadb'
ocDb="owncloud"  # name of the 'mariadb' database for 'owncloud'
ocDbUser="owncloud"  # name of the 'mariadb' user for 'owncloud'
ocDbUserPw="c0c0b7d"  # password for the 'mariadb' user for 'owncloud'

# 'apache' configuration variables
maxFileSize="1024M"  # max size of files that can be uploaded to 'owncloud'
apacheusrgrp=$(apachectl -S)  # get the status of 'apache' to determine the user and group it's running under
htuser=$(grep -i "user:" <<<"${apacheusrgrp}" | cut -d'"' -f2)  # get the user
htgroup=$(grep -i "group:" <<<"${apacheusrgrp}" | cut -d'"' -f2)  # get the group

# 'owncloud' configuration variables
ocAdminUser="rtruell"  # name of the 'owncloud' administrator
ocAdminUserPw="c0c0b7d"  # password for the 'owncloud' administrator
ocDir="/var/www/owncloud"  # where 'owncloud' lives
ocDataDir="/nas/owncloud-server/"  # where the user files are kept
logTimeZone="America/Edmonton"  # the time zone - defaults to UTC, which is bad
logFile="/var/log/owncloud.log"  # path where the 'owncloud' log should be saved

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
  print_warn "'/var/lib/mysql' has files/directories in it\n"
  if [[ "$(ls -A /nas/mysql)" ]]; then  # there were some, so check for files/directories in '/nas/mysql'
    print_warn "'/nas/mysql' has files/directories in it\n"
    sudo diff -q /var/lib/mysql /nas/mysql >/dev/null  # there were some, so compare the directories
    if [[ "${?}" == 0 ]]; then  # if the directories are identical
      print_result "${?}" "The directories are identical"  # say so
    else
      print_warn "The directories are different\n"  # otherwise, warn that the directories are different
      sudo cp -a /var/lib/mysql /var/lib/mysql.orig  # and back up '/var/lib/mysql' for later comparison
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

# configure 'php' for 'apache'
phpversion=$(ls /etc/php | cut -d '/' -f 1)  # get the version of 'php' that's being used
phpini="/etc/php/${phpversion}/apache2/php.ini"  # the 'php' configuration file full pathname
if [[ $(grep -i edmonton "${phpini}" ]]; then  # if the changes have already been made
  print_result "${?}" "'php' already configured for 'apache'"  # say so
else
  cp -a "${phpini}" "${phpini}".orig  # otherwise, back up the configuration file just in case
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
    -i "${phpini}"  # and make the changes
  print_result "${?}" "'php' configured for 'apache'"
fi
sudo systemctl start mariadb  # changes to the config are done, so start 'mariadb' again
print_result "${?}" "'mariadb' restarted"

# check to see if the 'owncloud' database exists.  if it does, then 'mariadb'
# has been secured and its root password has been set as well.  if not, do both
# of those items and then create the 'owncloud' database
if [[ $(sudo mysqlshow | grep -io owncloud) ]]; then  # if the 'owncloud' database already exists
  print_result "${?}" "The 'owncloud' database already exists, so 'mariadb' has been secured and its root password set as well"  # say so
else
  # Set 'mariadb' root password with 'debconf-set-selections'
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${mysqlRootPw}" # password for the 'mariadb' root user
  retcode1="${?}"
  sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${mysqlRootPw}" # repeat password for the 'mariadb' root user
  retcode2="${?}"
  if [[ "${retcode1}" == 0 && "${retcode2}" == 0 ]]; then
    retcode=0
  else
    retcode=1
  fi
  print_result "${retcode}" "'mariadb' root password set"

  # secure 'mariadb'
  sudo mysql --user=root --password=${mysqlRootPw} << SECURE_MARIADB
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
    FLUSH PRIVILEGES;
SECURE_MARIADB
  print_result "${?}" "'mariadb' secured"

  # create the 'owncloud' database
  sudo mysql --user=root --password=${mysqlRootPw} <<CREATE_DATABASE
    CREATE DATABASE ${ocDb};
    CREATE USER ${ocDbUser}@localhost IDENTIFIED BY '${ocDbUserPw}';
    GRANT ALL PRIVILEGES ON ${ocDb}.* TO ${ocDbUser}@localhost;
    FLUSH PRIVILEGES;
CREATE_DATABASE
  print_result "${?}" "'owncloud' database created"
fi

# change the 'apache' upload and post maximum filesizes plus the memory limit in
# the .htaccess file
apachehtaccess="/var/www/owncloud/.htaccess"  # the .htaccess file full pathname
sudo cp -a "${apachehtaccess}" "${apachehtaccess}".orig  # back it up just in case
sudo sed -E \
  -e "s/php_value upload_max_filesize .*/php_value upload_max_filesize ${maxFileSize}/" \
  -e "s/php_value post_max_size .*/php_value post_max_size ${maxFileSize}/" \
  -e "s/php_value memory_limit .*/php_value memory_limit ${maxFileSize}/" \
  -i "${apachehtaccess}"  # make the changes
print_result "${?}" "'apache' upload and post maximum filesizes changed"

# create the 'owncloud' site file for 'apache' if necessary
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

# create the 'owncloud' data directory, if necessary
if [[ -d "${ocDataDir}" ]]; then
  print_result "${?}" "'${ocDataDir}' already exists"
else
  sudo mkdir "${ocDataDir}"
  print_result "${?}" "'${ocDataDir}' created"
  sudo chown ${htuser}:${htgroup} ${ocDataDir}
  print_result "${?}" "'${ocDataDir}' ownership changed"
fi

# configure 'owncloud'
owncloudconfig="/var/www/owncloud/config/config.php"  # the 'owncloud' configuration file full pathname
if [[ $(grep -i edmonton "${owncloudconfig}" ]]; then  # if the changes have already been made
  print_result "${?}" "'owncloud' already configured"  # say so
else  # otherwise, make all the configuration changes
  cp -a "${owncloudconfig}" "${owncloudconfig}".orig # back up the configuration file just in case

  # 'owncloud' database configuration (see:
  # https://doc.owncloud.com/server/10.11/admin_manual/configuration/server/occ_command.html#command-description )
  sudo -u ${htuser} "${ocDir}"/occ maintenance:install \
    --database "mysql" \
    --database-name "${ocDb}" \
    --database-user "${ocDbUser}" \
    --database-pass "${ocDbUserPw}" \
    --admin-user "${ocAdminUser}" \
    --admin-pass "${ocAdminUserPw}" \
    --data-dir "${ocDataDir}" >/dev/null
  print_result "${?}" "Configured 'owncloud'"

  # configure the 'owncloud' trusted domains, if necessary
  if [[ "$(sudo grep -iq "${computername}" "${owncloudconfig}")" == 0 ]]; then  # if this computer is already in the trusted domains list
    print_result "${?}" "'${computername}' is already in the 'owncloud' trusted domains list"  # say so
  else  # otherwise, add it
    readarray -t trusteddomains < <(sudo -u ${htuser} "${ocDir}"/occ config:system:get trusted_domains)  # get a list of the current trusted domains
    numberdomains=${#trusteddomains[@]}  # get the number of domains already trusted
    sudo -u "${htuser}" "${ocDir}"/occ config:system:set trusted_domains "${numberdomains}" --value="${computername}" >/dev/null  # add this computer to the list
    print_result "${?}" "'${computername}' has been added to the 'owncloud' trusted domains list"
  fi

  # configure the 'owncloud' logfile
  logFileMasked=$(printf '%s' "${logFile}" | sed 's/\//\\\//g')  # escape the slashes in the log pathname
  logTimezoneMasked=$(printf '%s' "${logTimeZone}" | sed 's/\//\\\//g')  # escape the slashes in the timezone
  # change the timezone and add the logfile pathname and log level
  sudo sed -i "s/  'logtimezone' => 'UTC',/  'logtimezone' => '${logTimezoneMasked}',\n  'logfile' => '${logFileMasked}',\n  'loglevel' => '2',/" "${owncloudconfig}"
  print_result "${?}" "Configured 'owncloud' logfile"
  sudo touch "${logFile}"  # create the logfile
  print_result "${?}" "Created 'owncloud' logfile"
  sudo chown "${htuser}":"${htgroup}" "${logFile}"  # change the ownership of the logfile
  print_result "${?}" "'owncloud' logfile ownership changed"

  # configure 'owncloud' to use apcu
  sudo sed -i "s/);/  'memcache.local' => '\\\OC\\\Memcache\\\APCu',\n);/" "${owncloudconfig}"
  print_result "${?}" "Configured 'owncloud' to use 'apcu'"
fi

sudo a2enmod rewrite headers env dir mime unique_id >/dev/null  # enable 'apache' modules needed for 'owncloud'
print_result "${?}" "Enabled 'apache' modules needed for 'owncloud'"
sudo a2ensite owncloud >/dev/null  # enable the 'owncloud' site
print_result "${?}" "enabled the 'owncloud' site"
sudo systemctl restart apache2  # restart 'apache'
print_result "${?}" "Restarted 'apache'"
sudo systemctl status apache2  # show the status of 'apache'
print_result "${?}" "Checked the status of 'apache'"
sudo systemctl is-enabled mariadb >/dev/null # check to see if 'mariadb' is enabled
print_result "${?}" "Checked to make sure 'mariadb' is enabled"
sudo systemctl status mariadb  # show the status of 'mariadb'
print_result "${?}" "Checked the status of 'mariadb'"
