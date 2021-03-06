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

# add the repository for Docker to 'apt'
sudo "${HOME}"/bin/add-apt-key https://download.docker.com/linux/debian/gpg docker "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
print_result $? "Added the Docker repository to 'apt'"

# add the repository for Beyond Compare to 'apt'
sudo "${HOME}"/bin/add-apt-key https://www.scootersoftware.com/RPM-GPG-KEY-scootersoftware bcompare "deb https://www.scootersoftware.com/ bcompare4 non-free"
print_result $? "Added the Beyond Compare repository to 'apt'"

# update apt to pick up the new repositories, and then do an upgrade, just in
# case.  one of the times this script was run caused a problem I've never had
# before...a program prevented 'apt' from locking a directory, which
# prevented 'apt' from updating the source file lists, which would have caused
# this script to fail when trying to install programs from the just-added
# repositories.  so, had to implement a check to make sure 'apt' could update
# itself before continuing on.  and while I was at it, figured I'd better put in
# a check for the 'apt upgrade' as well
retcode=1
while [[ "${retcode}" != 0 ]]; do
  sudo apt update
  retcode=$?
done
print_result "${retcode}" "apt updated"
retcode=1
while [[ "${retcode}" != 0 ]]; do
  sudo apt upgrade
  retcode=$?
done
print_result "${retcode}" "apt upgraded"

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
currdir=${PWD}  # preserve the current directory
if [[ -d /nas/data/OSInstallFiles ]]; then  # if the NAS files are available
  print_result 0 "NAS files are available"
  cd /nas/data/OSInstallFiles  # change to the directory containing the files/directories to be copied
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
  cp -a smb.conf-nas "${HOME}"/smb.conf
  print_result $? "Copied the samba config file"

  # copy the ddclient config file to $HOME...it'll be put where it belongs
  # later, after 'ddclient' is installed
  cp -a ddclient.conf "${HOME}"
  print_result $? "Copied the ddclient config file"

  # copy programs that aren't available via 'apt'.  the programs must be
  # previously downloaded and located in '/nas/data/Downloads/Linux/InUse/Installed/Automated'
  declare -a programs=(
    "archey"
  )
  i=""
  programdir="/nas/data/Downloads/Linux/InUse/Installed/Automated"  # the directory containing the programs to be copied
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
  cp -a /nas/data/Downloads/TeraByte/InUse/Installed/ifl_en_cui_x64* "${programtmp}"
  print_result $? "Copied IFL"

  # now copy over the files needed for running the necessary web apps under
  # Docker, and create the symlink to move Docker's storage off of the SSD
  declare -a webapps=(
    "apt-cacher-ng"
    "mariadb"
    "owncloud"
    "redis"
    "shaarli"
  )
  i=""
  for i in ${webapps[@]}; do  # loop through the array of webapps to be installed ...
    cp -a "/nas/data/Downloads/Linux/InUse/Installed/Manual/Docker/nas/${i}.docker" "${HOME}"  # ... copying them to the user's HOME directory
    print_result $? "Copied ${i}"
  done
  cp -a /nas/data/Downloads/Linux/InUse/Installed/Manual/Docker/nas/docker-compose.yaml "${HOME}"  # copy the Docker Compose .yaml file ...
  print_result $? "Copied 'docker-compose.yaml'"
  chmod 600 "${HOME}"/docker-compose.yaml  # ... and set its permissions
  print_result $? "Set permissions for 'docker-compose.yaml'"
  sudo ln -s /nas/docker /var/lib/docker
  print_result $? "Created the symlink to get Docker storage off of the SSD"

  # done with the NAS files
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"
else
  print_result 1 "The NAS files aren't available...sensitive files/directories and non-apt programs must be copied manually"
fi

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

# install software from the repositories
for progname in $(sed -e 's/#.*//' -e '/^$/d' "${HOME}"/.APTfile.nas); do
  apt_package_installer "${progname}"
  if [[ "${progname}" == "bcompare" ]]; then
    # Beyond Compare installs a repository file for use with 'apt' that
    # conflicts with the one installed earlier, so get rid of the one that was
    # just installed
    sudo rm /etc/apt/sources.list.d/scootersoftware.list
    print_result $? "Deleted conflicting file '/etc/apt/sources.list.d/scootersoftware.list'"
  fi
done

# Now that Docker is installed, load the images for the web apps to be run and
# start them
cd "${HOME}"
for i in "${webapps[@]}"; do  # loop through the array of webapps to be installed ...
  sudo docker load -i "${i}.docker"  # ... and install them
  print_result $? "Installed ${i}"
  rm "${i}.docker"  # don't need this copy of the image file anymore, so delete it
  print_result $? "Deleted ${i} image file"
done
sudo docker compose up -d  # start the web apps

# add the user to the 'docker' group so they don't have to use 'sudo'.  this
# doesn't take effect until the user logs out and back in...which they'll be
# doing once this script is done
sudo usermod -aG docker "${username}"
print_result $? "Added '${username}' to the 'docker' group"

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
# so now '/etc/default/ddclient' is changed so that 'ddclient' only checks for a
# new external IP address once an hour, instead of every 5 minutes
sudo sed -E 's/(daemon_interval=).*/\1"1h"/' -i /etc/default/ddclient
print_result $? "Changed the delay value for 'ddclient'"

# Add the user to samba so they can access files on this computer from other
# computers
sudo smbpasswd -a "${username}"
print_result $? "Added '${username}' to samba"

# Create mount points for the 'data' and 'backups' directories on nasbackup
mkdir -p "${HOME}"/nasbackup/data
print_result $? "Created 'nasbackup/data'"
mkdir -p "${HOME}"/nasbackup/backups
print_result $? "Created 'nasbackup/backups'"

# Adding mount commands for the nasbackup shares to '/etc/fstab'
sudo cp /etc/fstab /etc/fstab.orig  # backup '/etc/fstab' just in case
print_result $? "Backed up '/etc/fstab'"
printf '%s\n' " " | sudo tee -a /etc/fstab >/dev/null  # add a separator line
print_result $? "Added separator line to '/etc/fstab'"
printf '%s\n' "# Mount nasbackup shares" | sudo tee -a /etc/fstab >/dev/null  # add a comment saying what the new section is for
print_result $? "Added comment explaining the new section to '/etc/fstab'"
printf '%s\n' "//nasbackup/data ${HOME}/nasbackup/data cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'data'
print_result $? "Added mount command for the 'data' directory on nasbackup to '/etc/fstab'"
printf '%s\n' "//nasbackup/backups ${HOME}/nasbackup/backups cifs rw,user,noauto,exec,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null  # mount command for 'backups'
print_result $? "Added mount command for the 'backups' directory on nasbackup to '/etc/fstab'"

# update the locate database
sudo updatedb
print_result $? "updated the 'locate' database"

exec 1>&3 2>&4 3>&- 4>&-  # restore stdout (1) and stderr (2) and close the "backup" file descriptors (3 & 4)
