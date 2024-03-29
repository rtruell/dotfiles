#!/usr/bin/env bash

# if installing to 'nas' or 'nasbackup', 'XMLTV' and 'apt-cacher-ng' get
# installed, so create any necessary directories, check to make sure data and
# configuration files aren't going to be clobbered, and mount the data and
# configuration directories off the SSD
if [[ "${computername}" == "nas"* ]]; then
  # move the data directory for 'XMLTV' off the SSD
  if [[ -d /nas/xmltv ]]; then  # if '/nas/xmltv' exists
    print_result "${?}" "'/nas/xmltv' already exists"  # say so
  else
    mkdir /nas/xmltv  # otherwise, create it
    print_result "${?}" "'/nas/xmltv' created"
  fi
  if [[ -d "${HOME}"/.xmltv ]]; then  # if '"${HOME}"/.xmltv' exists
    print_result "${?}" "'${HOME}/.xmltv' already exists"  # say so
  else
    mkdir "${HOME}"/.xmltv  # otherwise, create it
    print_result "${?}" "'${HOME}/.xmltv' created"
  fi
  if [[ "$(ls -A ${HOME}/.xmltv)" ]]; then  # check for files/directories in '"${HOME}"/.xmltv'
    print_warn "'${HOME}/.xmltv' has files/directories in it\n"
    if [[ "$(ls -A /nas/xmltv)" ]]; then  # there were some, so check for files/directories in '/nas/xmltv'
      print_warn "'/nas/xmltv' has files/directories in it\n"
      diff -q "${HOME}"/.xmltv /nas/xmltv >/dev/null  # there were some, so compare the directories
      if [[ "${?}" == 0 ]]; then  # if the directories are identical
        print_result "${?}" "The directories are identical"  # say so
      else
        print_warn "The directories are different\n"  # otherwise, warn that the directories are different
        sudo cp -a "${HOME}"/.xmltv "${HOME}"/.xmltv.orig  # and back up '"${HOME}"/.xmltv' for later comparison
        print_result "${?}" "Backed up '"${HOME}"/.xmltv' for later comparison"
      fi
      sudo rm -rf "${HOME}"/.xmltv/*  # delete the files/directories in '"${HOME}"/.xmltv'
      print_result "${?}" "Deleted the files/directories in '"${HOME}"/.xmltv'"
    else
      sudo mv "${HOME}"/.xmltv/* /nas/xmltv  # move 'xmltv' data files to their new location off the SSD
      print_result "${?}" "Moved 'xmltv' data files to '/nas/xmltv"
    fi
  fi
  sudo mount --bind /nas/xmltv "${HOME}"/.xmltv  # mount the 'xmltv' directory off the SSD
  print_result "${?}" "Mounted '/nas/xmltv' -> '${HOME}/.xmltv'"

  # install and configure 'apt-cacher-ng'
  apt_package_installer "apt-cacher-ng"  # install 'apt-cacher-ng'
  sudo systemctl stop apt-cacher-ng  # stop 'apt-cacher-ng' to make configuration changes
  print_result "${?}" "Stopped 'apt-cacher-ng'"
  if [[ -d /nas/apt-cacher-ng/data ]]; then  # if '/nas/apt-cacher-ng/data' exists
    print_result "${?}" "'/nas/apt-cacher-ng/data' already exists"  # say so
  else
    sudo mkdir -p /nas/apt-cacher-ng/data  # otherwise, create it
    print_result "${?}" "'/nas/apt-cacher-ng/data' created"
    sudo chown apt-cacher-ng:apt-cacher-ng /nas/apt-cacher-ng/data  # and change ownership of the new data directory
    print_result "${?}" "Chanaged ownership of '/nas/apt-cacher-ng/data'"
  fi
  if [[ -d /nas/apt-cacher-ng/config ]]; then  # if '/nas/apt-cacher-ng/config' exists
    print_result "${?}" "'/nas/apt-cacher-ng/config' already exists"  # say so
  else
    sudo mkdir -p /nas/apt-cacher-ng/config  # otherwise, create it
    print_result "${?}" "'/nas/apt-cacher-ng/config' created"
  fi
  if [[ "$(ls -A /var/cache/apt-cacher-ng)" ]]; then  # check for files/directories in '/var/cache/apt-cacher-ng'
    print_warn "'/var/cache/apt-cacher-ng' has files/directories in it\n"
    if [[ "$(ls -A /nas/apt-cacher-ng/data)" ]]; then  # there were some, so check for files/directories in '/nas/apt-cacher-ng/data'
      print_warn "'/nas/apt-cacher-ng/data' has files/directories in it\n"
      diff -q /var/cache/apt-cacher-ng /nas/apt-cacher-ng/data >/dev/null  # there were some, so compare the directories
      if [[ "${?}" == 0 ]]; then  # if the directories are identical
        print_result "${?}" "The directories are identical"  # say so
      else
        print_warn "The directories are different\n"  # otherwise, warn that the directories are different
        sudo cp -a /var/cache/apt-cacher-ng /var/cache/apt-cacher-ng.orig  # and back up '/var/cache/apt-cacher-ng' for later comparison
        print_result "${?}" "Backed up '/var/cache/apt-cacher-ng' for later comparison"
      fi
      sudo rm -rf /var/cache/apt-cacher-ng/*  # delete the files/directories in '/var/cache/apt-cacher-ng'
      print_result "${?}" "Deleted the files/directories in '/var/cache/apt-cacher-ng'"
    else
      sudo mv /var/cache/apt-cacher-ng/* /nas/apt-cacher-ng/data  # move 'apt-cacher-ng' data files to their new location off the SSD
      print_result "${?}" "Moved 'apt-cacher-ng' data files to '/nas/apt-cacher-ng/data'"
    fi
  fi
  sudo mount --bind /nas/apt-cacher-ng/data /var/cache/apt-cacher-ng  # mount the new 'apt-cacher-ng' data directory location to the old one
  print_result "${?}" "Mounted '/nas/apt-cacher-ng/data' -> '/var/cache/apt-cacher-ng'"
  if [[ "$(ls -A /etc/apt-cacher-ng)" ]]; then  # check for files/directories in '/etc/apt-cacher-ng'
    print_warn "'/etc/apt-cacher-ng' has files/directories in it\n"
    if [[ "$(ls -A /nas/apt-cacher-ng/config)" ]]; then  # there were some, so check for files/directories in '/nas/apt-cacher-ng/config'
      print_warn "'/nas/apt-cacher-ng/config' has files/directories in it\n"
      sudo diff -q /etc/apt-cacher-ng /nas/apt-cacher-ng/config >/dev/null  # there were some, so compare the directories
      if [[ "${?}" == 0 ]]; then  # if the directories are identical
        print_result "${?}" "The directories are identical"  # say so
      else
        print_warn "The directories are different\n"  # otherwise, warn that the directories are different
        sudo cp -a /etc/apt-cacher-ng /etc/apt-cacher-ng.orig  # and back up '/etc/apt-cacher-ng' for later comparison
        print_result "${?}" "Backed up '/etc/apt-cacher-ng' for later comparison"
      fi
      sudo rm /etc/apt-cacher-ng/*  # delete the files/directories in '/etc/apt-cacher-ng'
      print_result "${?}" "Deleted the files/directories in '/etc/apt-cacher-ng'"
    else
      sudo mv /etc/apt-cacher-ng/* /nas/apt-cacher-ng/config  # move 'apt-cacher-ng' configuration files to their new location off the SSD
      print_result "${?}" "Moved 'apt-cacher-ng' configuration files to '/nas/apt-cacher-ng/config'"
    fi
  fi
  sudo mount --bind /nas/apt-cacher-ng/config /etc/apt-cacher-ng  # mount the new 'apt-cacher-ng' configuration directory location to the old one
  print_result "${?}" "Mounted '/nas/apt-cacher-ng/config' -> '/etc/apt-cacher-ng'"
  sudo cp -a /etc/apt-cacher-ng/acng.conf /etc/apt-cacher-ng/acng.conf.orig  # back up the configuration file, just in case
  print_result "${?}" "'apt-cacher-ng' config file backed up"
  printf '\n%s\n' "# Allow data pass-through mode to CONNECT to everything" | sudo tee -a /etc/apt-cacher-ng/acng.conf >/dev/null  # add a separator line and header for a new section to the configuration file
  print_result "${?}" "Added a blank separator line and a header for the new section"
  printf '%s\n' "PassThroughPattern: .*" | sudo tee -a /etc/apt-cacher-ng/acng.conf >/dev/null  # add a pattern for 'pass-through' mode
  print_result "${?}" "Added pattern for pass-through mode"
  sudo systemctl start apt-cacher-ng  # changes to the config are done, so start 'apt-cacher-ng' again
  print_result "${?}" "'apt-cacher-ng' restarted"
fi

# add third-party software repositories to 'apt'
source ./addrepos.sh
print_result "${?}" "Software repositories added"

# install some packages, if necessary, so everything in the rest of this script
# can be done
declare -a packages=(
  "build-essential"
  "curl"
  "dialog"
  "dmidecode"
  "file"
  "gnupg"
  "linux-headers-amd64"
  "locate"
  "make"
  "openssh-server"
  "procps"
  "systemd"
)

# if installing on 'nas' or 'nasbackup', then 'ownCloud' server and 'shaarli'
# will be installed, so the packages they require get added to the packages
# array and installed now
if [[ "${computername}" == "nas"* ]]; then
  # packages needed to run 'ownCloud' server.  in addition to these, 'curl' is
  # also needed, but since it's already in the array to be installed, it's not
  # repeated here.  'apache2' was probably installed during the OS installation,
  # but since it's needed, we'll just make sure it gets installed
  packages+=(
    "apache2"
    "libapache2-mod-php"
    "mariadb-server"
    "php"
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
    "unzip"
    "owncloud-complete-files"
  )

  # packages needed to run 'shaarli'.  in addition to these, 'apache2',
  # 'libapache2-mod-php', 'php-curl', 'php-gd', 'php-intl', 'php-mbstring' and
  # 'php-zip' are also needed, but since they're already in the array to be
  # installed, they're not repeated here.  'openssl' was probably installed
  # during the OS installation, but since it's needed, we'll just make sure it
  # gets installed
  packages+=(
    "openssl"
    "php-ctype"
    "php-iconv"
    "php-json"
    "php-simplexml"
  )
fi

for i in ${packages[@]}; do  # loop through the array of packages ...
  apt_package_installer "${i}"  # ... installing them if necessary
done

# install any '.deb' programs that were copied, since they're easy to do in a
# script
shopt -s dotglob
shopt -s nullglob
filenames=("${programtmp}"/*.deb)  # get a list of all the '.deb' files in the '/tmp/programs' directory into an array.  filenames are of the format "/tmp/programs/<program>.deb"
shopt -u nullglob
for i in "${filenames[@]}"; do  # loop through all the '.deb' files that were found ...
  yes | sudo apt install "${i}"  # ... installing them, automatically answering 'yes' to any prompts ...
  print_result "${?}" "Installed ${i}"  # ... and printing a message giving the status of the installation
  rm "${i}"  # don't need this copy of the program installation file anymore, so delete it
  print_result "${?}" "Deleted ${i}"
done

# change the timeout value in 'grub'
sudo cp /etc/default/grub /etc/default/grub.orig  # back up '/etc/default/grub', just in case
print_result "${?}" "Backed up '/etc/default/grub'"
sudo sed -E 's/(GRUB_TIMEOUT=).*/\110/' -i /etc/default/grub  # change the timeout to 10 seconds, regardless of what it was
print_result "${?}" "Changed the timeout value for 'grub'"
sudo update-grub  # update grub so the new value takes effect
print_result "${?}" "Updated 'grub'"

# if not installing on a Raspberry Pi, install IFL
if [[ "${computername}" != "rpi"* ]]; then
  ifldir="${HOME}/ifl"
  [[ -d "${ifldir}" ]]  # check to see if the directory to install IFL in exists
  retcode="${?}"
  if [[ "${retcode}" == 0 ]]; then
    print_result retcode "'${ifldir}' exists"  # it exists
  else
    mkdir "${ifldir}"  # it doesn't exist, so create it
    print_result "${?}" "Created '${ifldir}'"
  fi
  sudo cp -a /etc/grub.d/40_custom /etc/grub.d/40_custom-orig  # back up '/etc/grub.d/40_custom'
  print_result "${?}" "Backed up '/etc/grub.d/40_custom'"
  sudo cp -a /boot/grub/grub.cfg /boot/grub/grub.cfg-orig  # back up '/boot/grub/grub.cfg'
  print_result "${?}" "Backed up '/boot/grub/grub.cfg'"
  unzip -d "${ifldir}" "${programtmp}"/ifl*.zip >/dev/null  # install IFL
  print_result "${?}" "Installed IFL"
  rm "${programtmp}"/ifl*.zip  # don't need the IFL installation file anymore, so delete it
  print_result "${?}" "Deleted the IFL installation file"
  currdir=${PWD}  # preserve the current directory
  cd "${ifldir}"  # change to the IFL directory
  print_result "${?}" "Changed to '${ifldir}'"
  unzip config.zip >/dev/null  # unzip the configuration files
  print_result "${?}" "Installed IFL's configuration files"
  mv config.txt config.txt.orig  # backup 'config.txt'
  print_result "${?}" "Backed up 'config.txt'"
  for i in ${iflconfigfiles[@]}; do
    mv ../"${i}" .  # move the license and config files to where they belong
    print_result "${?}" "Moved '${i}' to '${ifldir}'"
    chmod 644 "${i}"  # make sure the file permissions are set properly
    print_result "${?}" "Set the file permissions for '${i}'"
  done
  mv ../daily-backup ./scripts  # move the backup script to where it belongs
  print_result "${?}" "Moved 'daily-backup' to '${ifldir}/scripts'"

  # IFL has some dependencies which need to be installed
  declare -a dependencies=(
    "lib32z1"
    "libncursesw5:i386"
    "libstdc++6:i386"
  )
  sudo dpkg --add-architecture i386  # IFL needs the 32-bit shared libraries, so add the i386 architecture to get to them
  print_result "${?}" "i386 architecture added to apt"
  retcode=1
  while [[ "${retcode}" != 0 ]]; do
    sudo apt update  # update 'apt' so the libraries can be installed, and make sure the update actually happened
    retcode="${?}"
  done
  print_result "${retcode}" "apt updated"
  for i in "${dependencies[@]}"; do  # loop through the array of dependencies to be installed ...
    yes | sudo apt install "${i}"  # ... installing them, automatically answering 'yes' to any prompts ...
    print_result "${?}" "Installed ${i}"  # ... and printing a message giving the status of the installation
  done

  # configure IFL
  sudo ./setup
  print_result "${?}" "Configured IFL"

  # add the user to the 'disk' group so IFL can be run without 'sudo'
  sudo adduser "${username}" disk >/dev/null
  print_result "${?}" "Added '${username}' to the 'disk' group"

  # create and install the GRUB files
  clear
  sudo ./makeGRUB
  print_result "${?}" "Created and installed the GRUB files"

  # change back to where we were
  cd "${currdir}"
  print_result "${?}" "Changed back to '${currdir}'"
fi

# set the RTC to local time
sudo timedatectl set-local-rtc 1
print_result "${?}" "RTC set to local time"

# change the port number for 'sshd'
if [[ -d /etc/ssh/sshd_config.d ]]; then  # check to see if the directory '/etc/ssh/sshd_config.d' exists
  print_result "${?}" "'/etc/ssh/sshd_config.d' exists"
  if [[ -e /etc/ssh/sshd_config.d/port.conf ]]; then  # it does, so check to see if the file with the port number change is already in it
    print_result "${?}" "'/etc/ssh/sshd_config.d/port.conf' exists"
  else
    printf "Port 22000  # change the port in an attempt to foil crackers\n" | sudo tee /etc/ssh/sshd_config.d/port.conf >/dev/null  # it isn't, so create the file
    print_result "${?}" "Created '/etc/ssh/sshd_config.d/port.conf'"
    sudo chmod 600 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
    print_result "${?}" "Changed permissions for '/etc/ssh/sshd_config.d/port.conf'"
  fi
else
  sudo mkdir -p /etc/ssh/sshd_config.d  # the directory doesn't exist, so create it
  print_result "${?}" "Created '/etc/ssh/sshd_config.d'"
  sudo chmod 755 /etc/ssh/sshd_config.d  # change its' permissions
  print_result "${?}" "Changed permissions for '/etc/ssh/sshd_config.d'"
  printf "Port 22000  # change the port in an attempt to foil crackers\n" | sudo tee /etc/ssh/sshd_config.d/port.conf >/dev/null  # create the file with the port number change
  print_result "${?}" "Created '/etc/ssh/sshd_config.d/port.conf'"
  sudo chmod 600 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
  print_result "${?}" "Changed permissions for '/etc/ssh/sshd_config.d/port.conf'"
fi

# change the servers the clock is synced to
sudo cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.orig  # back up '/etc/systemd/timesyncd.conf', just in case
print_result "${?}" "Backed up '/etc/systemd/timesyncd.conf'"
sudo sed -E 's/#(NTP=).*/\1firewall/' -i /etc/systemd/timesyncd.conf  # uncomment the NTP line and add 'firewall' as the main server to sync to
print_result "${?}" "Uncommented the 'NTP' line and added 'firewall'"
sudo sed -E 's/#(FallbackNTP=.*)/\1/' -i /etc/systemd/timesyncd.conf  # uncomment the FallbackNTP line in case 'firewall' is having problems
print_result "${?}" "Uncommented the 'FallbackNTP' line"
sudo systemctl restart systemd-timesyncd  # restart 'systemd-timesyncd' so the new values take effect
print_result "${?}" "Restarted 'systemd-timesyncd'"

# some special considerations if installing on a laptop or in Virtualbox
if [[ "${computername}" != "nas"* && "${computername}" != "rpi"* ]]; then
  # get the machine type
  machinetype=$(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f3)
  print_result "${?}" "Machine type is: ${machinetype}"
  case "${machinetype,,}" in
        laptop)
                # allow the laptop lid to be closed to blank the display without
                # putting the computer into 'sleep' mode
                if [[ -d /etc/systemd/logind.conf.d ]]; then  # check to see if the directory '/etc/systemd/logind.conf.d' exists
                  print_result "${?}" "'/etc/systemd/logind.conf.d' exists"
                  if [[ -e /etc/systemd/logind.conf.d/lid.conf ]]; then  # it does, so check to see if the file with the lid/suspend/hibernate commands is already in it
                    print_result "${?}" "'/etc/systemd/logind.conf.d/lid.conf' exists"
                  else
                    sudo cp "${HOME}"/dotfiles/lid.conf /etc/systemd/logind.conf.d/lid.conf >/dev/null  # it isn't, so copy the file
                    print_result "${?}" "Copied '/etc/systemd/logind.conf.d/lid.conf'"
                    sudo chmod 644 /etc/systemd/logind.conf.d/lid.conf  # and set its permissions
                    print_result "${?}" "Set permissions for '/etc/systemd/logind.conf.d/lid.conf'"
                  fi
                else
                  sudo mkdir -p /etc/systemd/logind.conf.d  # the directory doesn't exist, so create it
                  print_result "${?}" "Created '/etc/systemd/logind.conf.d'"
                  sudo chmod 755 /etc/systemd/logind.conf.d  # and set its' permissions
                  print_result "${?}" "Set permissions for '/etc/systemd/logind.conf.d'"
                  sudo cp "${HOME}"/dotfiles/lid.conf /etc/systemd/logind.conf.d/lid.conf >/dev/null  # copy the file with the lid/suspend/hibernate commands
                  print_result "${?}" "Copied '/etc/systemd/logind.conf.d/lid.conf'"
                  sudo chmod 644 /etc/systemd/logind.conf.d/lid.conf  # and set its permissions
                  print_result "${?}" "Set permissions for '/etc/systemd/logind.conf.d/lid.conf'"
                fi
                print_result "${?}" "Closing lid won't put computer into 'sleep' mode"
                sudo systemctl restart systemd-logind.service  # restart the service so the changes take effect immediately
                print_result "${?}" "Service restarted"

                # if installing on the Acer laptop
                if [[ $(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f5) == "Acer" ]]; then
                  yes | sudo apt install firmware-b43-installer  # install the wi-fi drivers
                  print_result "${?}" "Installed drivers for the wi-fi card"

                  # 64-bit Debian - and *only* 64-bit Debian - for some odd
                  # reason won't boot on the Acer laptop without blacklisting
                  # the 'acer_wmi' module.  so, check to see if running 64-bit
                  # Debian and if so, blacklist the module
                  if [[ $(getconf LONG_BIT) == 64 && $(lsb_release -is) == "Debian" ]]; then
                    printf "blacklist acer_wmi\n" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf >/dev/null  # create the blacklist file
                    print_result "${?}" "Created '/etc/modprobe.d/blacklist-acer_wmi.conf'"
                    sudo chmod 544 /etc/modprobe.d/blacklist-acer_wmi.conf  # and change its permissions
                    print_result "${?}" "Changed permissions for '/etc/modprobe.d/modprobe.conf'"
                  fi
                fi
                ;;
    virtualbox)
                # if the Guest Additions aren't installed, install them so the
                # window can be maximized, and to have bi-directional sharing of
                # folders and the clipboard
                if [[ $(lsmod | grep -i vboxsf) ]]; then
                  print_result "${?}" "Guest Additions installed"
                else
                  printf '%s\n' "Go to the 'Devices' menu and select 'Insert Guest Additions CD image...'"  # prompt to insert the CD image
                  read -n1 -r -p "Press any key once that's done."
                  sudo mount /dev/cdrom  # mount the CD image
                  print_result "${?}" "CD image mounted"
                  sudo sh /media/cdrom/VBoxLinuxAdditions.run  # run the installer
                  print_result "${?}" "Installed Guest Additions"
                  sudo umount /dev/cdrom  # unmount the CD image
                  print_result "${?}" "CD image unmounted"
                fi
                printf '\n%s\n' "Don't forget to maximize the screen after rebooting!"

                # if the user is not in the group 'vboxsf', add them so they're
                # able to access shared folders
                if [[ $(groups | grep vboxsf) ]]; then
                  print_result "${?}" "'${username}' is already in group 'vboxsf'"
                else
                  sudo adduser "${username}" vboxsf
                  print_result "${?}" "Added '${username}' to group 'vboxsf'"
                fi
                ;;
  esac
fi

# install software from the repositories.  got the idea for this from using
# a 'brewfile' with 'Homebrew' on macOS and wanted something similar for 'apt'
case "${computername}" in
  nas*) aptprogramlistfile="${HOME}/.APTfile.nas" ;;
  rpi*) aptprogramlistfile="${HOME}/.APTfile.rpi4b" ;;
     *) aptprogramlistfile="${HOME}/.APTfile" ;;
esac
for progname in $(sed -e 's/#.*//' -e '/^$/d' "${aptprogramlistfile}"); do
  apt_package_installer "${progname}"
  if [[ "${computername}" != "rpi"* ]]; then
    if [[ "${progname}" == "bcompare" ]]; then
      # Beyond Compare installs a repository file for use with 'apt' that
      # conflicts with the one installed earlier, so get rid of the one that was
      # just installed
      sudo rm /etc/apt/sources.list.d/scootersoftware.list
      print_result "${?}" "Deleted conflicting file '/etc/apt/sources.list.d/scootersoftware.list'"
    fi
  fi
done

# the 'samba' config file was copied to $HOME earlier.  now that 'samba' has
# been installed, the config file is moved to where it belongs
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.orig  # backup '/etc/samba/smb.conf' just in case
print_result "${?}" "Backed up '/etc/samba/smb.conf'"
sudo mv "${HOME}"/smb.conf /etc/samba/smb.conf  # move 'smb.conf' to where it belongs
print_result "${?}" "Moved the samba config file to where it belongs"
sudo chown root:root /etc/samba/smb.conf  # set the owner/group properly
print_result "${?}" "Set the owner/group for '/etc/samba/smb.conf'"
sudo chmod 644 /etc/samba/smb.conf  # set its permissions
print_result "${?}" "Set permissions for '/etc/samba/smb.conf'"

# Add the user to samba so they can access files on this computer from other
# computers
printf '%s\n' "Enter the SAMBA password for ${username}"
sudo smbpasswd -a "${username}"
print_result "${?}" "Added '${username}' to samba"

if [[ "${computername}" == "nas"* ]]; then
  # the 'ddclient' config file was copied to $HOME earlier.  now that 'ddclient'
  # has been installed, the config file is moved to where it belongs
  sudo mv /etc/ddclient.conf /etc/ddclient.conf.orig  # backup '/etc/ddclient.conf' just in case
  print_result "${?}" "Backed up '/etc/ddclient.conf'"
  sudo mv "${HOME}"/ddclient.conf /etc/ddclient.conf  # move 'ddclient.conf' to where it belongs
  print_result "${?}" "Moved the ddclient config file to where it belongs"
  sudo chown root:root /etc/ddclient.conf  # set the owner/group properly
  print_result "${?}" "Set the owner/group for '/etc/ddclient.conf'"
  sudo chmod 600 /etc/ddclient.conf  # set its permissions
  print_result "${?}" "Set permissions for '/etc/ddclient.conf'"

  # the settings in '/etc/default/ddclient' override ones set in
  # '/etc/ddclient.conf', even though it's supposed to be the other way around.
  # so now '/etc/default/ddclient' is changed so that 'ddclient' only checks for
  # a new external IP address once an hour, instead of every 5 minutes
  sudo sed -E 's/(daemon_interval=).*/\1"1h"/' -i /etc/default/ddclient
  print_result "${?}" "Changed the delay value for 'ddclient'"

  # if installing on 'nasbackup', 'ddclient' should be disabled so it won't
  # interfere with the instance running on 'nas'
  if [[ "${computername}" == "nasbackup" ]]; then
    sudo systemctl disable ddclient
    print_result "${?}" "Disabled 'ddclient' on 'nasbackup"
  fi

  # install 'ownCloud' server
  source ./ownCloudServer.sh

  # install 'shaarli'
  shaarlidir="/nas/Shaarli"  # shaarli install directory
  if [[ -d "${shaarlidir}" ]]; then  # if the install directory already exists
    print_warn "'${shaarlidir}' already exists\n"  # say so
    mv "${shaarlidir}" "${shaarlidir}".orig  # and back it up for later comparison
    print_result "${?}" "backed up '${shaarlidir}' for later comparison"
  fi
  sudo unzip -d /nas "${HOME}"/shaarli-full.zip >/dev/null  # install 'shaarli'
  print_result "${?}" "Installed 'shaarli'"
  sudo chown -R www-data:www-data "${shaarlidir}"  # change ownership of the 'shaarli' files and directories
  print_result "${?}" "Changed ownership of files and directories of 'shaarli'"
  sudo chmod -R g+rX "${shaarlidir}"  # add 'read' and 'execute' permissions for the group 'apache' runs under to the 'shaarli' files and directories
  print_result "${?}" "Changed permissions of files and directories of 'shaarli'"
  sudo chmod -R g+rwX "${shaarlidir}"/{cache/,data/,pagecache/,tmp/}  # add 'read', 'write' and 'execute' permissions for the group 'apache' runs under to the 'shaarli' cache, data and temp files and dirs
  print_result "${?}" "Changed permissions of the cache, data, pagecache and temp directories of 'shaarli'"
  if [[ -d /etc/apache2/sites-available/shaarli.conf ]]; then  # if the 'shaarli' web site configuration file for 'apache' exists
    print_warn "'/etc/apache2/sites-available/shaarli.conf' already exists\n"  # say so
    mv /etc/apache2/sites-available/shaarli.conf /etc/apache2/sites-available/shaarli.conf.orig  # and back it up for later comparison
    print_result "${?}" "backed up '/etc/apache2/sites-available/shaarli.conf' for later comparison"
  fi

  # create the 'shaarli' web site configuration file for 'apache'
  cat <<APACHE_SHAARLI_CONF | sudo tee /etc/apache2/sites-available/shaarli.conf >/dev/null
Alias /shaarli "${shaarlidir}"

<Directory "${shaarlidir}/">
  AllowOverride All
</Directory>
APACHE_SHAARLI_CONF
  print_result "${?}" "Created 'shaarli.conf'"
  sudo a2ensite shaarli >/dev/null  # enable the 'shaarli' web site
  print_result "${?}" "Enabled 'shaarli'"
  sudo a2enmod rewrite headers >/dev/null  # enable the 'apache' modules that 'shaarli' needs
  print_result "${?}" "Enabled needed Apache modules"
  sudo systemctl restart apache2  # restart 'apache'
  print_result "${?}" "Restarted Apache"
fi

# if not installing on nas, nasbackup or a Raspberry Pi
if [[ "${computername}" != "nas"* && "${computername}" != "rpi"* ]]; then
  # install 'VirtualBox'
  print_info "\tInstalling VirtualBox\n"
  print_info "\tRetrieving checksums and the latest version number\n"
  virboxversion="$(curl https://download.virtualbox.org/virtualbox/LATEST.TXT 2>/dev/null)"  # get the latest release version
  osreleasename="$(lsb_release -cs)"  # get the OS release name (buster, bullseye, etc)
  while read -r line; do  # read each line of the checksum file
    case "${line}" in
      *"${osreleasename}"* )  # if it's for the release of VirtualBox for this OS
        virboxcsum="${line% *}"  # extract the checksum
        virboxname="${line#* \*}"  # extract the filename
        virboxpath="${programtmp}/${virboxname}"  # create the pathname where VirtualBox will be temporarily stored
        ;;
      *"${virboxversion}".vbox* )  # if it's for the Extension Pack
        extpackcsum="${line% *}"  # extract the checksum
        extpackname="${line#* \*}"  # extract the filename
        extpackpath="${programtmp}/${extpackname}"  # create the pathname where the Extension Pack will be temporarily stored
        ;;
    esac
  done < <(curl https://download.virtualbox.org/virtualbox/"${virboxversion}"/SHA256SUMS 2>/dev/null)
  print_info "\tDownloading VirtualBox\n"
  curl https://download.virtualbox.org/virtualbox/"${virboxversion}"/"${virboxname}" -o "${virboxpath}" 2>/dev/null  # download VirtualBox
  if [[ "$(sha256sum "${virboxpath}" | cut -d' ' -f1)" != "${virboxcsum}" ]]; then  # check to see if the checksum of the downloaded file matches what it's supposed to
    print_result "${?}" "VirtualBox checksum doesn't match...VirtualBox and its Extension Pack must be downloaded and installed manually"
  else
    print_result "${?}" "Checksums match...successfully downloaded VirtualBox"
    print_info "\tDownloading the Extension Pack\n"
    extpackok=0
    curl https://download.virtualbox.org/virtualbox/"${virboxversion}"/"${extpackname}" -o "${extpackpath}" 2>/dev/null  # download the Extension Pack
    if [[ "$(sha256sum "${extpackpath}" | cut -d' ' -f1)" != "${extpackcsum}" ]]; then  # check to see if the checksum of the downloaded file matches what it's supposed to
      print_result "${?}" "Extension pack checksum doesn't match...the Extension Pack must be downloaded and installed manually"
      extpackok=1  # since the checksums didn't match, set a flag so no attempt is made to install the invalid Extension Pack
    else
      print_result "${?}" "Checksums match...successfully downloaded the VirtualBox Extension Pack"
    fi
    yes | sudo apt install "${virboxpath}"  # install VirtualBox, automatically answering 'yes' to any prompts
    retcode="${?}"
    print_result "${retcode}" "Installed VirtualBox"
    if [[ "${retcode}" != 0 ]]; then  # if VirtualBox didn't install properly ...
      if [[ "${extpackok}" == 0 ]]; then  # ... but the Extension Pack downloaded successfully ...
        print_warn "The Extension Pack must be installed manually after fixing the problem with installing VirtualBox"  # ... print a manual install notification
      fi
    else
      rm "${virboxpath}"  # VirtualBox installed successfully and this copy of the installation file isn't needed anymore, so delete it
      print_result "${?}" "Deleted ${virboxpath}"
      if [[ "${extpackok}" == 0 ]]; then  # if the Extension Pack downloaded successfully ...
        sudo VBoxManage extpack install --replace "${extpackpath}"  # ... try to install it
        retcode="${?}"
        print_result "${?}" "Installed the VirtualBox Extension Pack"
        if [[ "${retcode}" != 0 ]]; then  # oops...it didn't install successfully
          print_result "${retcode}" "The Extension Pack must be installed manually"
        else
          rm "${extpackpath}"  # it installed successfully and this copy of the installation file isn't needed anymore, so delete it
          print_result "${?}" "Deleted ${extpackpath}"
          sudo VBoxManage extpack cleanup  # probably not necessary after a new install, but never hurts to clean things up
          print_result "${?}" "Cleaned up the Extension Pack install"
        fi
      fi
    fi
  fi

  # the updated 'freeguide' .jar file was copied to $HOME earlier.  now that
  # 'freeguide' has been installed, the .jar file is moved to where it belongs
  freeguidejar="/usr/share/freeguide/FreeGuide.jar"
  sudo mv "${freeguidejar}" "${freeguidejar}".orig  # backup '/usr/share/freeguide/FreeGuide.jar' just in case
  print_result "${?}" "Backed up '${freeguidejar}'"
  sudo mv "${HOME}"/FreeGuide.jar "${freeguidejar}"  # move 'FreeGuide.jar' to where it belongs
  print_result "${?}" "Moved 'FreeGuide.jar' to where it belongs"
  sudo chown root:root "${freeguidejar}"  # set the owner/group properly
  print_result "${?}" "Set the owner/group for '${freeguidejar}'"
  sudo chmod 644 "${freeguidejar}"  # set its permissions
  print_result "${?}" "Set permissions for '${freeguidejar}'"
fi

# the Sublime Text 'User' directory is being shared between machines for a
# consistent usage environment, so symlink it
if [[ -d "${HOME}/.config/sublime-text/Packages/User" ]]; then  # if the 'User' directory already exists
  print_warn "The 'User' directory for 'sublime text' already exists\n"  # say so
  mv ${HOME}/.config/sublime-text/Packages/User ${HOME}/.config/sublime-text/Packages/User.old  # and back it up for later comparison
  print_result "${?}" "Backed it up for later comparison"
fi
symlink_single_file "${HOME}/dotfiles/SublimeText/User" "${HOME}/.config/sublime-text/Packages/User"  # symlink the 'User' directory

# Create mount points for the 'data' and 'backups' directories
if [[ "${computername}" == "nas" ]]; then
  nasdevice="nasbackup"
else
  nasdevice="nas"
fi
nasdatamountpoint="${HOME}/${nasdevice}/data"
nasbackupsmountpoint="${HOME}/${nasdevice}/backups"
mkdir -p "${nasdatamountpoint}"
print_result "${?}" "Created '${nasdatamountpoint}'"
mkdir -p "${nasbackupsmountpoint}"
print_result "${?}" "Created '${nasbackupsmountpoint}'"

# Add mount commands for the 'data' and 'backups' shares to '/etc/fstab'
sudo cp /etc/fstab /etc/fstab.orig  # backup '/etc/fstab' just in case
print_result "${?}" "Backed up '/etc/fstab'"
printf '%s\n' " " | sudo tee -a /etc/fstab >/dev/null  # add a separator line
print_result "${?}" "Added separator line to '/etc/fstab'"
printf '%s\n' "# Mount ${nasdevice} shares" | sudo tee -a /etc/fstab >/dev/null  # add a comment saying what the new section is for
print_result "${?}" "Added comment explaining the new section to '/etc/fstab'"
printf '%s\n' "//${nasdevice}/data ${nasdatamountpoint} cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'data'
print_result "${?}" "Added mount command for the 'data' directory on ${nasdevice} to '/etc/fstab'"
printf '%s\n' "//${nasdevice}/backups ${nasbackupsmountpoint} cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'backups'
print_result "${?}" "Added mount command for the 'backups' directory on ${nasdevice} to '/etc/fstab'"

# Add mount commands to '/etc/fstab' to bind the new, off-SSD data directories
# to the original ones for the programs that are likely to have a lot of data
printf '\n%s\n' "# Mount off-SSD data directories for programs with lots of data" | sudo tee -a /etc/fstab >/dev/null  # add a blank separator line and a header for the new section
print_result "${?}" "Added a blank separator line and a header for the new section to '/etc/fstab'"
printf '%s\n' "/nas/xmltv ${HOME}/.xmltv none bind 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for XMLTV
print_result "${?}" "Added mount command for XMLTV to '/etc/fstab'"
printf '%s\n' "/nas/mysql /var/lib/mysql none bind 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for Mariadb
print_result "${?}" "Added mount command for Mariadb to '/etc/fstab'"
printf '%s\n' "/nas/apt-cacher-ng/data /var/cache/apt-cacher-ng none bind 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for apt-cacher-ng data
print_result "${?}" "Added mount command for 'apt-cacher-ng' data to '/etc/fstab'"
printf '%s\n' "/nas/apt-cacher-ng/config /etc/apt-cacher-ng none bind 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for apt-cacher-ng config
print_result "${?}" "Added mount command for 'apt-cacher-ng' config to '/etc/fstab'"

# update the locate database
sudo updatedb
print_result "${?}" "updated the 'locate' database"
