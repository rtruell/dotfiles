#!/usr/bin/env bash

if [[ "${computername}" == "nas"* ]]; then
  # add some symlinks to get files off the SSD, even though most of the
  # programs using them won't be installed until later.
  symlink_single_file "/nas/xmltv" "${HOME}/.xmltv"  # TV listings xml files and databases
  symlink_single_file "/nas/mysql" "/var/lib/mysql"  # Mariadb
  symlink_single_file "/nas/apt-cacher-ng/data" "/var/cache/apt-cacher-ng"  # apt-cacher-ng data directory
  symlink_single_file "/nas/apt-cacher-ng/config" "/etc/apt-cacher-ng"  # apt-cacher-ng config directory
  # install and configure 'apt-cacher-ng'
  apt_package_installer "apt-cacher-ng"  # install 'apt-cacher-ng'
  print_result $? "'apt-cacher-ng' installed"
  sudo cp /etc/apt-cacher-ng/acng.conf /etc/apt-cacher-ng/acng.conf.orig  # back up the config file, just in case
  print_result $? "config file backed up"
  printf '\n%s\n' "Allow data pass-through mode to CONNECT to everything" | sudo tee -a /etc/apt-cacher-ng/acng.conf >/dev/null
  print_result $? "Added header for new section"
  printf '%s\n' "PassThroughPattern: .*" | sudo tee -a /etc/apt-cacher-ng/acng.conf >/dev/null
  print_result $? "Added pattern for pass-through mode"
  sudo systemctl restart apt-cacher-ng  # restart 'apt-cacher-ng' to pick up the changes made to the config
  print_result $? "'apt-cacher-ng' restarted"
fi
# add third-party software repositories to 'apt'
source ./addrepos.sh
print_result $? "Software repositories added"
# if installing onto 'nas' or 'nasbackup', docker gets installed
if [[ "${computername}" == "nas"* ]]; then source ./docker-nas.sh; print_result $? "Docker installed"; fi
# install some packages, if necessary, so everything in the rest of this
# script can be done
declare -a packages=(
  "build-essential"
  "curl"
  "dmidecode"
  "file"
  "gnupg"
  "inxi"
  "linux-headers-amd64"
  "locate"
  "make"
  "openssh-server"
  "procps"
  "systemd"
)
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
  print_result $? "Installed ${i}"  # ... and printing a message giving the status of the installation
  rm "${i}"  # don't need this copy of the program installation file anymore, so delete it
  print_result $? "Deleted ${i}"
done

# change the timeout value in 'grub'
sudo cp /etc/default/grub /etc/default/grub.orig  # back up '/etc/default/grub', just in case
print_result $? "Backed up '/etc/default/grub'"
sudo sed -E 's/(GRUB_TIMEOUT=).*/\110/' -i /etc/default/grub  # change the timeout to 10 seconds, regardless of what it was
print_result $? "Changed the timeout value for 'grub'"
sudo update-grub  # update grub so the new value takes effect
print_result $? "Updated 'grub'"

# if not installing on a Raspberry Pi, install IFL
if [[ "${computername}" != "rpi"* ]]; then
  ifldir="${HOME}/ifl"
  [[ -d "${ifldir}" ]]  # check to see if the directory to install IFL in exists
  retcode=$?
  if [[ "${retcode}" == 0 ]]; then
    print_result retcode "'${ifldir}' exists"  # it exists
  else
    mkdir "${ifldir}"  # it doesn't exist, so create it
    print_result $? "Created '${ifldir}'"
  fi
  sudo cp -a /etc/grub.d/40_custom /etc/grub.d/40_custom-orig  # back up '/etc/grub.d/40_custom'
  print_result $? "Backed up '/etc/grub.d/40_custom'"
  sudo cp -a /boot/grub/grub.cfg /boot/grub/grub.cfg-orig  # back up '/boot/grub/grub.cfg'
  print_result $? "Backed up '/boot/grub/grub.cfg'"
  unzip -d "${ifldir}" "${programtmp}"/ifl*.zip >/dev/null  # install IFL
  print_result $? "Installed IFL"
  rm "${programtmp}"/ifl*.zip  # don't need the IFL installation file anymore, so delete it
  print_result $? "Deleted the IFL installation file"
  cd "${ifldir}"  # change to the IFL directory
  print_result $? "Changed to '${ifldir}'"
  unzip config.zip >/dev/null  # unzip the configuration files
  print_result $? "Installed IFL's configuration files"
  mv config.txt config.txt.orig  # backup 'config.txt'
  print_result $? "Backed up 'config.txt'"
  for i in ${iflconfigfiles[@]}; do
    mv ../"${i}" .  # move the license and config files to where they belong
    print_result $? "Moved '${i}' to '${ifldir}'"
    chmod 644 "${i}"  # make sure the file permissions are set properly
    print_result $? "Set the file permissions for '${i}'"
  done
  mv ../daily-backup ./scripts  # move the backup script to where it belongs
  print_result $? "Moved 'daily-backup' to '${ifldir}/scripts'"

  # IFL has some dependencies which need to be installed
  declare -a dependencies=(
    "lib32z1"
    "libncursesw5:i386"
    "libstdc++6:i386"
  )
  sudo dpkg --add-architecture i386  # IFL needs the 32-bit shared libraries, so add the i386 architecture to get to them
  print_result $? "i386 architecture added to apt"
  retcode=1
  while [[ "${retcode}" != 0 ]]; do
    sudo apt update  # update 'apt' so the libraries can be installed, and make sure the update actually happened
    retcode=$?
  done
  print_result "${retcode}" "apt updated"
  for i in "${dependencies[@]}"; do  # loop through the array of dependencies to be installed ...
    yes | sudo apt install "${i}"  # ... installing them, automatically answering 'yes' to any prompts ...
    print_result $? "Installed ${i}"  # ... and printing a message giving the status of the installation
  done

  # configure IFL
  sudo ./setup
  print_result $? "Configured IFL"

  # add the user to the 'disk' group so IFL can be run without 'sudo'
  sudo adduser "${username}" disk
  print_result $? "Added '${username}' to the 'disk' group"

  # create and install the GRUB files
  sudo ./makeGRUB
  print_result $? "Created and installed the GRUB files"
fi

# set the RTC to local time
sudo timedatectl set-local-rtc 1
print_result $? "RTC set to local time"

# change the port number for 'sshd'
if [[ -d /etc/ssh/sshd_config.d ]]; then  # check to see if the directory '/etc/ssh/sshd_config.d' exists
  print_result $? "'/etc/ssh/sshd_config.d' exists"
  if [[ -e /etc/ssh/sshd_config.d/port.conf ]]; then  # it does, so check to see if the file with the port number change is already in it
    print_result $? "'/etc/ssh/sshd_config.d/port.conf' exists"
  else
    printf "Port 22000  # change the port in an attempt to foil crackers\n" | sudo tee /etc/ssh/sshd_config.d/port.conf >/dev/null  # it isn't, so create the file
    print_result $? "Created '/etc/ssh/sshd_config.d/port.conf'"
    sudo chmod 600 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
    print_result $? "Changed permissions for '/etc/ssh/sshd_config.d/port.conf'"
  fi
else
  sudo mkdir /etc/ssh/sshd_config.d  # the directory doesn't exist, so create it
  print_result $? "Created '/etc/ssh/sshd_config.d'"
  sudo chmod 755 /etc/ssh/sshd_config.d  # change its' permissions
  print_result $? "Changed permissions for '/etc/ssh/sshd_config.d'"
  printf "Port 22000  # change the port in an attempt to foil crackers\n" | sudo tee /etc/ssh/sshd_config.d/port.conf >/dev/null  # create the file with the port number change
  print_result $? "Created '/etc/ssh/sshd_config.d/port.conf'"
  sudo chmod 600 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
  print_result $? "Changed permissions for '/etc/ssh/sshd_config.d/port.conf'"
fi

# change the servers the clock is synced to
sudo cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.orig  # back up '/etc/systemd/timesyncd.conf', just in case
print_result $? "Backed up '/etc/systemd/timesyncd.conf'"
sudo sed -E 's/#(NTP=).*/\1firewall/' -i /etc/systemd/timesyncd.conf  # uncomment the NTP line and add 'firewall' as the main server to sync to
print_result $? "Uncommented the 'NTP' line and added 'firewall'"
sudo sed -E 's/#(FallbackNTP=.*)/\1/' -i /etc/systemd/timesyncd.conf  # uncomment the FallbackNTP line in case 'firewall' is having problems
print_result $? "Uncommented the 'FallbackNTP' line"
sudo systemctl restart systemd-timesyncd  # restart 'systemd-timesyncd' so the new values take effect
print_result $? "Restarted 'systemd-timesyncd'"

# some special considerations if installing on a laptop or in Virtualbox
if [[ "${computername}" != "nas"* && "${computername}" != "rpi"* ]]; then
  # get the machine type
  machinetype=$(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f3)
  print_result $? "Machine type is: ${machinetype}"
  case "${machinetype,,}" in
        laptop)
                # allow the laptop lid to be closed to blank the display without
                # putting the computer into 'sleep' mode
                if [[ -d /etc/systemd/logind.conf.d ]]; then  # check to see if the directory '/etc/systemd/logind.conf.d' exists
                  print_result $? "'/etc/systemd/logind.conf.d' exists"
                  if [[ -e /etc/systemd/logind.conf.d/lid.conf ]]; then  # it does, so check to see if the file with the lid/suspend/hibernate commands is already in it
                    print_result $? "'/etc/systemd/logind.conf.d/lid.conf' exists"
                  else
                    sudo cp "${HOME}"/dotfiles/lid.conf /etc/systemd/logind.conf.d/lid.conf >/dev/null  # it isn't, so copy the file
                    print_result $? "Copied '/etc/systemd/logind.conf.d/lid.conf'"
                    sudo chmod 644 /etc/systemd/logind.conf.d/lid.conf  # and set its permissions
                    print_result $? "Set permissions for '/etc/systemd/logind.conf.d/lid.conf'"
                  fi
                else
                  sudo mkdir /etc/systemd/logind.conf.d  # the directory doesn't exist, so create it
                  print_result $? "Created '/etc/systemd/logind.conf.d'"
                  sudo chmod 755 /etc/systemd/logind.conf.d  # and set its' permissions
                  print_result $? "Set permissions for '/etc/systemd/logind.conf.d'"
                  sudo cp "${HOME}"/dotfiles/lid.conf /etc/systemd/logind.conf.d/lid.conf >/dev/null  # copy the file with the lid/suspend/hibernate commands
                  print_result $? "Copied '/etc/systemd/logind.conf.d/lid.conf'"
                  sudo chmod 644 /etc/systemd/logind.conf.d/lid.conf  # and set its permissions
                  print_result $? "Set permissions for '/etc/systemd/logind.conf.d/lid.conf'"
                fi
                print_result 0 "Closing lid won't put computer into 'sleep' mode"
                sudo systemctl restart systemd-logind.service  # restart the service so the changes take effect immediately
                print_result $? "Service restarted"

                # if installing on the Acer laptop
                if [[ $(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f5) == "Acer" ]]; then
                  yes | sudo apt install firmware-b43-installer  # install the wi-fi drivers
                  print_result $? "Installed drivers for the wi-fi card"

                  # 64-bit Debian - and *only* 64-bit Debian - for some odd
                  # reason won't boot on the Acer laptop without blacklisting
                  # the 'acer_wmi' module.  so, check to see if running 64-bit
                  # Debian and if so, blacklist the module
                  if [[ $(getconf LONG_BIT) == 64 && $(lsb_release -is) == "Debian" ]]; then
                    printf "blacklist acer_wmi\n" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf >/dev/null  # create the blacklist file
                    print_result $? "Created '/etc/modprobe.d/blacklist-acer_wmi.conf'"
                    sudo chmod 544 /etc/modprobe.d/blacklist-acer_wmi.conf  # and change its permissions
                    print_result $? "Changed permissions for '/etc/modprobe.d/modprobe.conf'"
                  fi
                fi
                ;;
    virtualbox)
                # if the Guest Additions aren't installed, install them so the
                # window can be maximized, and to have bi-directional sharing of
                # folders and the clipboard
                if [[ $(lsmod | grep -i vboxsf) ]]; then
                  print_result $? "Guest Additions installed"
                else
                  printf '%s\n' "Go to the 'Devices' menu and select 'Insert Guest Additions CD image...'"  # prompt to insert the CD image
                  read -n1 -r -p "Press any key once that's done."
                  sudo mount /dev/cdrom  # mount the CD image
                  print_result $? "CD image mounted"
                  sudo sh /media/cdrom/VBoxLinuxAdditions.run  # run the installer
                  print_result $? "Installed Guest Additions"
                  sudo umount /dev/cdrom  # unmount the CD image
                  print_result $? "CD image unmounted"
                fi
                printf '\n%s\n' "Don't forget to maximize the screen after rebooting!"

                # if the user is not in the group 'vboxsf', add them so they're
                # able to access shared folders
                if [[ $(groups | grep vboxsf) ]]; then
                  print_result $? "'${username}' is already in group 'vboxsf'"
                else
                  sudo adduser "${username}" vboxsf
                  print_result $? "Added '${username}' to group 'vboxsf'"
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
      print_result $? "Deleted conflicting file '/etc/apt/sources.list.d/scootersoftware.list'"
    fi
  fi
done

# the 'samba' config file was copied to $HOME earlier.  now that 'samba' has
# been installed, the config file is moved to where it belongs
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.orig  # backup '/etc/samba/smb.conf' just in case
print_result $? "Backed up '/etc/samba/smb.conf'"
sudo mv "${HOME}"/smb.conf /etc/samba/smb.conf  # move 'smb.conf' to where it belongs
print_result $? "Moved the samba config file to where it belongs"
sudo chown root:root /etc/samba/smb.conf  # set the owner/group properly
print_result $? "Set the owner/group for '/etc/samba/smb.conf'"
sudo chmod 644 /etc/samba/smb.conf  # set its permissions
print_result $? "Set permissions for '/etc/samba/smb.conf'"

# Add the user to samba so they can access files on this computer from other
# computers
printf '%s\n' "Enter the SAMBA password for ${username}"
sudo smbpasswd -a "${username}"
print_result $? "Added '${username}' to samba"

if [[ "${computername}" == "nas" ]]; then
  # the 'ddclient' config file was copied to $HOME earlier.  now that 'ddclient'
  # has been installed, the config file is moved to where it belongs
  sudo mv /etc/ddclient.conf /etc/ddclient.conf.orig  # backup '/etc/ddclient.conf' just in case
  print_result $? "Backed up '/etc/ddclient.conf'"
  sudo mv "${HOME}"/ddclient.conf /etc/ddclient.conf  # move 'ddclient.conf' to where it belongs
  print_result $? "Moved the ddclient config file to where it belongs"
  sudo chown root:root /etc/ddclient.conf  # set the owner/group properly
  print_result $? "Set the owner/group for '/etc/ddclient.conf'"
  sudo chmod 600 /etc/ddclient.conf  # set its permissions
  print_result $? "Set permissions for '/etc/ddclient.conf'"

  # the settings in '/etc/default/ddclient' override ones set in
  # '/etc/ddclient.conf', even though it's supposed to be the other way around.
  # so now '/etc/default/ddclient' is changed so that 'ddclient' only checks for
  # a new external IP address once an hour, instead of every 5 minutes
  sudo sed -E 's/(daemon_interval=).*/\1"1h"/' -i /etc/default/ddclient
  print_result $? "Changed the delay value for 'ddclient'"

  # install ownCloud
  source ./ownCloudServer.sh
fi

# if not installing on nas, nasbackup or a Raspberry Pi, install VirtualBox
if [[ "${computername}" != "nas"* && "${computername}" != "rpi"* ]]; then
  printf '\t%s\n' "Installing VirtualBox"
  printf '\t%s\n' "Retrieving checksums and the latest version number"
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
  printf '\t%s\n' "Downloading VirtualBox"
  curl https://download.virtualbox.org/virtualbox/"${virboxversion}"/"${virboxname}" -o "${virboxpath}" 2>/dev/null  # download VirtualBox
  if [[ "$(sha256sum "${virboxpath}" | cut -d' ' -f1)" != "${virboxcsum}" ]]; then  # check to see if the checksum of the downloaded file matches what it's supposed to
    print_result $? "Error: VirtualBox checksum doesn't match...VirtualBox and its Extension Pack must be downloaded and installed manually"
  else
    print_result $? "Checksums match...successfully downloaded VirtualBox"
    printf '\t%s\n' "Downloading the Extension Pack"
    extpackok=0
    curl https://download.virtualbox.org/virtualbox/"${virboxversion}"/"${extpackname}" -o "${extpackpath}" 2>/dev/null  # download the Extension Pack
    if [[ "$(sha256sum "${extpackpath}" | cut -d' ' -f1)" != "${extpackcsum}" ]]; then  # check to see if the checksum of the downloaded file matches what it's supposed to
      print_result $? "Error: Extension pack checksum doesn't match...the Extension Pack must be downloaded and installed manually"
      extpackok=1  # since the checksums didn't match, set a flag so no attempt is made to install the invalid Extension Pack
    else
      print_result $? "Checksums match...successfully downloaded the VirtualBox Extension Pack"
    fi
    yes | sudo apt install "${virboxpath}"  # install VirtualBox, automatically answering 'yes' to any prompts
    retcode="$?"
    print_result "${retcode}" "Installed VirtualBox"
    if [[ "${retcode}" != 0 ]]; then  # if VirtualBox didn't install properly ...
      if [[ "${extpackok}" == 0 ]]; then  # ... but the Extension Pack downloaded successfully ...
        print_warn "${retcode}" "The Extension Pack must be installed manually after fixing the problem with installing VirtualBox"  # ... print a manual install notification
      fi
    else
      rm "${virboxpath}"  # VirtualBox installed successfully and this copy of the installation file isn't needed anymore, so delete it
      print_result $? "Deleted ${virboxpath}"
      if [[ "${extpackok}" == 0 ]]; then  # if the Extension Pack downloaded successfully ...
        sudo VBoxManage extpack install --replace "${extpackpath}"  # ... try to install it
        retcode="$?"
        print_result $? "Installed the VirtualBox Extension Pack"
        if [[ "${retcode}" != 0 ]]; then  # oops...it didn't install successfully
          print_result "${retcode}" "Error: The Extension Pack must be installed manually"
        else
          rm "${extpackpath}"  # it installed successfully and this copy of the installation file isn't needed anymore, so delete it
          print_result $? "Deleted ${extpackpath}"
          sudo VBoxManage extpack cleanup  # probably not necessary after a new install, but never hurts to clean things up
          print_result $? "Cleaned up the Extension Pack install"
        fi
      fi
    fi
  fi
fi

# Create mount points for the 'data' and 'backups' directories
if [[ "${computername}" == "nas" ]]; then
  nasdevice="nasbackup"
else
  nasdevice="nas"
fi
nasdatamountpoint="${HOME}/${nasdevice}/data"
nasbackupsmountpoint="${HOME}/${nasdevice}/backups"
mkdir -p "${nasdatamountpoint}"
print_result $? "Created '${nasdatamountpoint}'"
mkdir -p "${nasbackupsmountpoint}"
print_result $? "Created '${nasbackupsmountpoint}'"

# Adding mount commands for the 'data' and 'backups' shares to '/etc/fstab'
sudo cp /etc/fstab /etc/fstab.orig  # backup '/etc/fstab' just in case
print_result $? "Backed up '/etc/fstab'"
printf '%s\n' " " | sudo tee -a /etc/fstab >/dev/null  # add a separator line
print_result $? "Added separator line to '/etc/fstab'"
printf '%s\n' "# Mount ${nasdevice} shares" | sudo tee -a /etc/fstab >/dev/null  # add a comment saying what the new section is for
print_result $? "Added comment explaining the new section to '/etc/fstab'"
printf '%s\n' "//${nasdevice}/data ${nasdatamountpoint} cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'data'
print_result $? "Added mount command for the 'data' directory on ${nasdevice} to '/etc/fstab'"
printf '%s\n' "//${nasdevice}/backups ${nasbackupsmountpoint} cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'backups'
print_result $? "Added mount command for the 'backups' directory on ${nasdevice} to '/etc/fstab'"

# update the locate database
sudo updatedb
print_result $? "updated the 'locate' database"
