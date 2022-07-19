#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# Linux-only stuff.  abort if not Linux.
if [[ "$(uname)" != "Linux" ]]; then printf '%s\n' "This script is to be run only on Linux"; exit 1; fi

# save stdout (1) and stderr (2) in "backup" file descriptors (3 & 4), and then
# redirect them so that the output and any error messages from the script are on
# both the screen and in a file...just in case there are errors that need to be
# referenced later.
exec 3>&1 4>&2  > >(tee -i "${HOME}"/installlog.txt) 2>&1

# some functions are needed to set things up, so load them
source ./.functions/answer_is_y.function
source ./.functions/apt_package_installer.function
source ./.functions/execute_command.function
source ./.functions/01#findcommand.function
source ./.functions/print_error.function
source ./.functions/print_result.function
source ./.functions/print_success.function
source ./.functions/print_warn.function
source ./.functions/symlink_array_files.function
source ./.functions/symlink_single_file.function

# ANSI sequences for colours to be used in the banner
declare -a colours=(
  "\033[0;30m"
  "\033[1;30m"
  "\033[0;36m"
  "\033[0;34m"
  "\033[0;31m"
  "\033[0;32m"
  "\033[0;35m"
  "\033[0;33m"
  "\033[1;33m"
  "\033[0;37m"
)

# a banner display in the style as shown in the movie "Matrix"...although not
# nearly as good :-)
for z in {1..40}; do
  for i in {1..17}; do
    r="$(($RANDOM % 2))"
    if [[ $(($RANDOM % 5)) == 1 ]]; then
      if [[ $(($RANDOM % 4)) == 1 ]]; then
        v+="${colours[$((1 + $RANDOM % 10))]} ${r}   "
      else
        v+="${colours[$((1 + $RANDOM % 10))]} ${r}   "
      fi
    else
      v+="${colours[$((1 + $RANDOM % 10))]}     "
    fi
  done
  printf "${v}\n"
  sleep .1
  v="";
done

# emphasize that this is a new install :-)
declare -a words=(
  " #    # ###### #    #     #####  #    #  ####  #####    ##   #      #        ### ###"
  " ##   # #      #    #       #    ##   # #        #     #  #  #      #        ### ###"
  " # #  # #####  #    #       #    # #  #  ####    #    #    # #      #        ### ###"
  " #  # # #      # ## #       #    #  # #      #   #    ###### #      #        ### ###"
  " #   ## #      ##  ##       #    #   ## #    #   #    #    # #      #               "
  " #    # ###### #    #     #####  #    #  ####    #    #    # ###### ######   ### ###"
)
printf "\033[0m\n"
for i in "${words[@]}"; do
  printf '%s\n' "${i}"
  sleep .1
done
printf '%s\n' " "
unset colours words z i r v

# get the users login name
username=$(echo ${USER})
print_result $? "User doing the install is '${username}'"

# make it so the user can use 'sudo'.  the code that was in here suddenly
# stopped working, so it was removed and put into its own script file.  it's
# actually better that way...'su -c' can only run "one" command at a time, so
# if doing multiple things is required, either there has to be multiple 'su -c'
# lines and type the password each time, or there has to be one humongous
# command line.  using an external script, the password only has to be typed
# once, but each command can be on its own line, making it easier to follow
# what's being done and to debug problems
su -c 'source ./sudo.sh'

# symlink the dotfiles into ${HOME}
source ./symlink.sh
print_result $? "Symlinked dotfiles"

# discovered when installing from the Debian 11.2.0 DVD that the installer
# didn't comment out all of the installation media lines in
# '/etc/apt/sources.list', causing a problem when doing an 'apt update', so I
# fix that here.  as well, I want access to the packages in the 'contrib' and
# 'non-free' repositories, so I add them to the repository lines here as well
sudo mv /etc/apt/sources.list /etc/apt/sources.list.orig  # back up 'sources.list', just in case
print_result $? "Backed up '/etc/apt/sources.list'"
while read -r repoline; do  # read in /etc/apt/sources.list.orig one line at a time
  if [[ ${repoline} == *"cdrom:"* ]]; then  # if it's a line for the installation media, comment it out, even if it's already commented out...more "#"'s don't hurt, less do
    repoline="#"${repoline}
  fi
  if [[ ${repoline} == "deb"* ]]; then  # if it's a line for one of the repositories
    if [[ ${repoline} != *"contrib"* ]]; then  # if 'contrib' isn't there, add it
      repoline+=" contrib"
    fi
    if [[ ${repoline} != *"non-free"* ]]; then  # if 'non-free' isn't there, add it
      repoline+=" non-free"
    fi
  fi
  printf '%s\n' "${repoline}" | sudo tee -a /etc/apt/sources.list >/dev/null  # print the (possibly updated) line to a new '/etc/apt/sources.list'
done < /etc/apt/sources.list.orig
print_result 0 "Updated '/etc/apt/sources.list' with the 'contrib' and 'non-free' repositories, and commented out the installation media lines"

# add the repository for Webmin to 'apt'
sudo "${HOME}"/bin/add-apt-key https://download.webmin.com/jcameron-key.asc webmin "deb https://download.webmin.com/download/repository sarge contrib"
print_result $? "Added the Webmin repository to 'apt'"

# add the repository for Sublime Text/Merge to 'apt'
sudo "${HOME}"/bin/add-apt-key https://download.sublimetext.com/sublimehq-pub.gpg sublimehq "deb https://download.sublimetext.com/ apt/stable/"
print_result $? "Added the Sublime Text/Merge repository to 'apt'"

# add the repository for VirtualBox to 'apt'.  note that '$(lsb_release -cs)' is
# replaced with the name of the current release, ie. 'buster', 'bullseye', etc.
sudo "${HOME}"/bin/add-apt-key https://www.virtualbox.org/download/oracle_vbox_2016.asc virtualbox "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
print_result $? "Added the VirtualBox repository to 'apt'"

# add the repository for Beyond Compare to 'apt'
sudo "${HOME}"/bin/add-apt-key https://www.scootersoftware.com/RPM-GPG-KEY-scootersoftware bcompare "deb https://www.scootersoftware.com/ bcompare4 non-free"
print_result $? "Added the Beyond Compare repository to 'apt'"

# update apt to pick up the new repositories, and then do an upgrade
sudo apt update
print_result $? "apt updated"
sudo apt upgrade
print_result $? "apt upgraded"

# install some packages, if necessary, so everything in the rest of this script
# can be done
declare -a packages=(
  "build-essential"
  "cifs-utils"
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

# Copy over the files and directories that are needed but shouldn't be in a
# public repository, as well as software not in a repository but that has been
# downloaded
declare -a filesdirs=(
  ".credentials"
  ".gitconfig.local"
  ".ssh"
)
i=""
retcode=0
currdir=${PWD}  # preserve the current directory
mkdir "${HOME}"/mountpoint  # create a mount point for the NAS' data directory ...
print_result $? "Created mount point"
sudo mount -t cifs -o user=rtruell //nas/data "${HOME}"/mountpoint  # ... and mount it.  don't forget to change the user name as necessary
retcode=$?
if [[ "${retcode}" == 0 ]]; then  # if the NAS was mounted
  print_result ${retcode} "Mounted NAS"
  cd "${HOME}"/mountpoint/OSInstallFiles  # change to the directory containing the files/directories to be copied
  print_result $? "Changed to the directory containing the sensitive files/directories to be copied"
  for i in ${filesdirs[@]}; do  # loop through the array of files and directories to be copied
    if [[ -d "${i}" ]]; then  # if it's a directory
      cp -ra "${i}" "${HOME}"  # copy it and all its files
      print_result $? "Copied directory ${i}"
      chmod 700 "${HOME}/${i}"  # set the permissions on the directory itself to read/write/execute for the owner and nothing for others
      print_result $? "Set permissions for the ${i} directory"
      chmod 600 "${HOME}/${i}"/*  # set the permissions on the files in the directory to read/write for the owner and nothing for others
      print_result $? "Set permissions for the files in the ${i} directory"
    else  # otherwise it's a file
      cp -a "${i}" "${HOME}"  # copy it
      print_result $? "Copied ${i}"
      chmod 600 "${HOME}/${i}"  # set its permissions to read/write for the owner and nothing for others
      print_result $? "Set permissions for ${i}"
    fi
  done

  # copy config files for Beyond Compare
  if [[ ! -d "${HOME}"/.config/bcompare ]]; then  # if '.config/bcompare' doesn't exist
    mkdir "${HOME}"/.config/bcompare  # create it
    print_result $? "Created '.config/bcompare'"
    chmod 755 "${HOME}"/.config/bcompare  # and set its permissions
    print_result $? "Set permissions for '.config/bcompare'"
  else
    print_result 0 "'.config/bcompare' exists"
  fi
  cp -a BC4Key.txt "${HOME}"/.config/bcompare
  print_result $? "Copied the Beyond Compare key file to '"${HOME}"/.config/bcompare'"
  chmod 600 "${HOME}"/.config/bcompare/BC4Key.txt
  print_result $? "Set permissions for the Beyond Compare key file"
  cp -a BCSettings-lin*.bcpkg "${HOME}"
  print_result $? "Copied the Beyond Compare settings file"
  chmod 600 "${HOME}"/BCSettings-lin*.bcpkg
  print_result $? "Set permissions for the Beyond Compare settings file"

  # copy the samba config file to $HOME...it'll be put where it belongs later,
  # after 'samba' is installed
  cp -a smb.conf "${HOME}"/smb.conf
  print_result $? "Copied the samba config file"

  # copy programs that aren't available via 'apt'.  the programs must be
  # previously downloaded and located in '${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated'
  declare -a programs=(
    "archey"
    "freequide"
    "google-earth"
    "imager"
    "usbimager"
    "zulu"
  )
  i=""
  programdir="${HOME}/mountpoint/Downloads/Linux/InUse/Installed/Automated"  # the directory containing the programs to be copied
  programtmp="/tmp/programs"  # temporary location to hold programs until installed
  if [[ ! -d "${programtmp}" ]]; then  # if the temporary location doesn't exist ...
    mkdir "${programtmp}"  # ... create it
    print_result $? "Created '${programtmp}'"
  else
    print_result 0 "'${programtmp}' exists"
  fi
  for i in ${programs[@]}; do  # loop through the array of programs to be installed ...
    cp -a "${programdir}/${i}"* "${programtmp}"  # ... copying them to '/tmp/programs'
    print_result $? "Copied ${i}"
  done

  # the Terabyte programs live in their own directory and thus can't be copied
  # during the above, so copy Image For Linux (IFL) separately
  cp -a "${HOME}"/mountpoint/Downloads/TeraByte/InUse/Installed/ifl_en_cui_x64* "${programtmp}"
  print_result $? "Copied IFL"

  # done with the NAS
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"
  sudo umount "${HOME}"/mountpoint  # unmount the NAS
  print_result $? "Unmounted NAS"
else
  print_result ${retcode} "Mounting NAS failed...sensitive files/directories and non-apt programs must be copied manually"
fi
rmdir "${HOME}"/mountpoint  # remove the mountpoint
print_result $? "Removed mount point"

# install any '.deb' programs that were just copied, since they're easy to do
# in a script
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

# install IFL
ifldir="${HOME}/ifl"
if [[ ! -d "${ifldir}" ]]; then  # if the directory to install IFL in doesn't exist ...
  mkdir "${ifldir}"  # ... create it
  print_result $? "Created '${ifldir}'"
else
  print_result 0 "'${ifldir}' exists"
fi
unzip -d "${ifldir}" "${programtmp}"/ifl*.zip  # install IFL
print_result $? "Installed IFL"
rm "${programtmp}"/ifl*.zip  # don't need the IFL installation file anymore, so delete it
print_result $? "Deleted the IFL installation file"

# IFL has some dependencies which need to be installed
declare -a dependencies=(
  "lib32z1"
  "libncursesw5:i386"
  "libstdc++6:i386"
)
sudo dpkg --add-architecture i386  # IFL needs the 32-bit shared libraries, so add the i386 architecture to get to them
sudo apt update  # update 'apt' so the libraries can be installed
for i in "${dependencies[@]}"; do  # loop through the array of dependencies to be installed ...
  yes | sudo apt install "${i}"  # ... installing them, automatically answering 'yes' to any prompts ...
  print_result $? "Installed ${i}"  # ... and printing a message giving the status of the installation
done
sudo adduser "${username}" disk  # add the user to the 'disk' group so IFL can access the devices

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

# change the timeout value in 'grub'
sudo cp /etc/default/grub /etc/default/grub.orig  # back up '/etc/default/grub', just in case
print_result $? "Backed up '/etc/default/grub'"
sudo sed -E 's/(GRUB_TIMEOUT=).*/\110/' -i /etc/default/grub  # change the timeout to 10 seconds, regardless of what it was
print_result $? "Changed the timeout value for 'grub'"
sudo update-grub  # update grub so the new value takes effect
print_result $? "Updated 'grub'"

# change the servers the clock is synced to
sudo cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.orig  # back up '/etc/systemd/timesyncd.conf', just in case
print_result $? "Backed up '/etc/systemd/timesyncd.conf'"
sudo sed -E 's/#(NTP=).*/\1firewall/' -i /etc/systemd/timesyncd.conf  # uncomment the NTP line and add 'firewall' as the main server to sync to
print_result $? "Uncommented the 'NTP' line and added 'firewall'"
sudo sed -E 's/#(FallbackNTP=.*)/\1/' -i /etc/systemd/timesyncd.conf  # uncomment the FallbackNTP line in case 'firewall' is having problems
print_result $? "Uncommented the 'FallbackNTP' line"
sudo systemctl restart systemd-timesyncd  # restart 'systemd-timesyncd' so the new values take effect
print_result $? "Restarted 'systemd-timesyncd'"

# get the machine type
machinetype=$(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f3)
print_result $? "Machine type is: ${machinetype}"

# commands dependent on the type of machine being installed
case "${machinetype}" in
      Laptop)
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

                # 64-bit Debian - and *only* 64-bit Debian - for some odd reason
                # won't boot on the Acer laptop without blacklisting the
                # 'acer_wmi' module.  so, check to see if running 64-bit Debian
                # and if so, blacklist the module
                if [[ $(getconf LONG_BIT) == 64 ]] && [[ $(lsb_release -is) == "Debian" ]]; then
                  printf "blacklist acer_wmi\n" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf >/dev/null  # create the blacklist file
                  print_result $? "Created '/etc/modprobe.d/blacklist-acer_wmi.conf'"
                  sudo chmod 544 /etc/modprobe.d/blacklist-acer_wmi.conf  # and change its permissions
                  print_result $? "Changed permissions for '/etc/modprobe.d/modprobe.conf'"
                fi
              fi
              ;;
  Virtualbox)
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
           *) ;;
esac

# install software from the repositories
for progname in $(sed -e 's/#.*//' -e '/^$/d' "${HOME}"/.APTfile); do
  apt_package_installer "${progname}"
  if [[ "${progname}" == "bcompare" ]]; then
    # Beyond Compare installs a repository file for use with 'apt' that
    # conflicts with the one installed earlier, so get rid of the one that was
    # just installed
    sudo rm /etc/apt/sources.list.d/scootersoftware.list
    print_result $? "Deleted conflicting file '/etc/apt/sources.list.d/scootersoftware.list'"
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
sudo smbpasswd -a "${username}"
print_result $? "Added '${username}' to samba"

# Create mount points for the 'data' and 'backups' directories on nas
mkdir -p "${HOME}"/nas/data
print_result $? "Created 'nas/data'"
mkdir -p "${HOME}"/nas/backups
print_result $? "Created 'nas/backups'"

# Adding mount commands for the nas shares to '/etc/fstab'
sudo cp /etc/fstab /etc/fstab.orig  # backup '/etc/fstab' just in case
print_result $? "Backed up '/etc/fstab'"
printf '%s\n' " " | sudo tee -a /etc/fstab >/dev/null  # add a separator line
print_result $? "Added separator line to '/etc/fstab'"
printf '%s\n' "# Mount nas shares" | sudo tee -a /etc/fstab >/dev/null  # add a comment saying what the new section is for
print_result $? "Added comment explaining the new section to '/etc/fstab'"
printf '%s\n' "//nas/data ${HOME}/nas/data cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'data'
print_result $? "Added mount command for the 'data' directory on nas to '/etc/fstab'"
printf '%s\n' "//nas/backups ${HOME}/nas/backups cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'backups'
print_result $? "Added mount command for the 'backups' directory on nas to '/etc/fstab'"

# update the locate database
sudo updatedb
print_result $? "updated the 'locate' database"

exec 1>&3 2>&4 3>&- 4>&-  # restore stdout (1) and stderr (2) and close the "backup" file descriptors (3 & 4)
