#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# Linux-only stuff.  abort if not Linux.
if [[ "$(uname)" != "Linux" ]]; then printf '%s\n' "This script is to be run only on Linux"; exit 1; fi

# have the output of the script both on the screen and in a file...just in case
# there are errors that need to be checked later
exec > >(tee -i ~/installlog.txt) 2>&1

# some of my functions are needed to set things up, so load them
source ./.functions/answer_is_yes.function
source ./.functions/execute_command.function
source ./.functions/findcommand.function
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
  for i in {1..16}; do
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
  v="";
done

# emphasize that this is a new install :-)
printf "\033[0m\n"
printf " #    # ###### #    #       # #    #  ####  #####   ##   #      #        ### ###\n"
printf " ##   # #      #    #       # ##   # #        #    #  #  #      #        ### ###\n"
printf " # #  # #####  #    #       # # #  #  ####    #   #    # #      #        ### ###\n"
printf " #  # # #      # ## #       # #  # #      #   #   ###### #      #        ### ###\n"
printf " #   ## #      ##  ##       # #   ## #    #   #   #    # #      #               \n"
printf " #    # ###### #    #       # #    #  ####    #   #    # ###### ######   ### ###\n"
printf "\n"
unset colours z i r v

# Check if '/usr/bin/sudo' exists. if not, try to find 'sudo' in the PATH and,
# if found, suggest a symlink. exit the script, whether it was found in the PATH
# or not
if [[ ! -f /usr/bin/sudo ]]; then
  if findcommand sudo &>/dev/null; then
    message="/usr/bin/sudo not found.  Please run 'sudo ln -s $(findcommand sudo) /usr/bin/sudo'"
  else
    message="/usr/bin/sudo not found, and I couldn't find 'sudo' anywhere in the PATH"
  fi
  print_result 1 "${message}" "true"
fi
print_result 0 "Found sudo"

# Check if '/bin/bash' exists. if not, try to find 'bash' in the PATH and, if
# found, suggest a symlink. exit the script, whether it was found in the PATH or
# not
if [[ ! -f /bin/bash ]]; then
  if findcommand bash &>/dev/null; then
    message="/bin/bash not found.  Please run 'sudo ln -s $(findcommand bash) /bin/bash'"
  else
    message="/bin/bash not found, and I couldn't find 'bash' anywhere in the PATH"
  fi
  print_result 1 "${message}" "true"
fi
print_result 0 "Found bash"

# get the name of the user doing the install
username=$(whoami)
print_result $? "user doing the install is: ${username}"

# make it so I can use 'sudo'...and without having to type my password
if [[ -d /etc/sudoers.d ]]; then  # if the directory '/etc/sudoers.d' exists
  print_result $? "'/etc/sudoers.d' exists"
  if [[ -e /etc/sudoers.d/rtruell ]]; then  # and the file with my 'sudo' permissions is already in it
    print_result $? "'/etc/sudoers.d/rtruell' exists"
  else
    su -c 'cp rtruell /etc/sudoers.d && chmod 440 /etc/sudoers.d/rtruell'  # copy the file and set its permissions
    retcode=$?  # preserve the return code
    message="Copied 'rtruell' to '/etc/sudoers.d' and changed its permissions"  # status message saying what the above commands did
    print_result "${retcode}" "${message}"
  fi
else
  # the directory doesn't exist, so add an 'includedir' directive to the end of
  # '/etc/sudoers', make the '/etc/sudoers.d' directory, set its permissions,
  # copy the file with my 'sudo' permissions, and set that files permissions
  su -c 'printf "\n%s\n" "#includedir /etc/sudoers.d" >>/etc/sudoers && mkdir /etc/sudoers.d && chmod 755 /etc/sudoers.d && cp rtruell /etc/sudoers.d && chmod 440 /etc/sudoers.d/rtruell'
  retcode=$?
  # status message saying what the above commands did.
  message="Added the necessary '#includedir' line to '/etc/sudoers', created '/etc/sudoers.d', changed its permissions, copied 'rtruell' to '/etc/sudoers.d' and changed its permissions"
  print_result "${retcode}" "${message}"
fi

# install some packages, if necessary, so everything in this script can be done
declare -a packages=(
  "build-essential"
  "cifs-utils"
  "curl"
  "dmidecode"
  "file"
  "inxi"
  "linux-headers-amd64"
  "locate"
  "make"
  "openssh-server"
  "procps"
)
for i in ${packages[@]}; do  # loop through the array of packages
  if [[ ! $(apt list --installed 2>/dev/null | grep "${i}") ]]; then  # if the package isn't already installed
   yes | sudo apt install "${i}"  # install it, automatically answering 'yes' to any prompts
   print_result $? "Installed ${i}"
 else  # the package is already installed
   print_result $? "${i} already installed"
 fi
done

# symlink the dotfiles into ${HOME}
source ./symlink.sh
print_result $? "Symlinked dotfiles"

# Copy over the files and directories that are needed but shouldn't be in a
# public repository
declare -a filesdirs=(
  ".credentials"
  ".gitconfig.local"
  ".ssh"
)
i=""
retcode=""
currdir=${PWD}  # preserve the current working directory
mkdir ~/mountpoint  # create a mount point for the NAS' data directory ...
print_result $? "Created mount point"
sudo mount -t cifs -o user=rtruell //fileserver/data /home/rtruell/mountpoint  # ... and mount it
retcode=$?
if [[ "${retcode}" == 0 ]]; then  # if the NAS was mounted
  print_result ${retcode} "Mounted NAS"
  cd ~/mountpoint/OSInstallFiles  # change to the directory containing the files/directories to be copied
  print_result $? "Changed to the directory containing the sensitive files/directories to be copied"
  for i in ${filesdirs[@]}; do  # loop through the array of files and directories
    if [[ -d "${i}" ]]; then  # if it's a directory
      cp -ra "${i}" ~  # copy it and all its files
      print_result $? "Copied directory ${i}"
      chmod 700 ~/"${i}"  # set the permissions on the directory itself to read/write/execute for the owner and nothing for others
      print_result $? "Set permissions for the ${i} directory"
      chmod 600 ~/"${i}"/*  # set the permissions on the files in the directory to read/write for the owner and nothing for others
      print_result $? "Set permissions for the files in the ${i} directory"
    else  # otherwise it's a file
      cp -a "${i}" ~  # copy it
      print_result $? "Copied ${i}"
      chmod 600 ~/"${i}"  # set its permissions to read/write for the owner and nothing for others
      print_result $? "Set permissions for ${i}"
    fi
  done
  sudo umount /home/rtruell/mountpoint  # unmount the NAS
  print_result $? "Unmounted NAS"
  cd "${currdir}"  # change back to where we were
else
  print_result ${retcode} "Mounting NAS failed...sensitive files/directories must be copied manually"
fi
rmdir ~/mountpoint
print_result $? "Removed mount point"

# set the RTC to local time
sudo timedatectl set-local-rtc 1
print_result $? "RTC set to local time"

# change the port number for 'sshd'
if [[ -d /etc/ssh/sshd_config.d ]]; then  # if the directory '/etc/ssh/sshd_config.d' exists
  print_result $? "'/etc/ssh/sshd_config.d' exists"
  if [[ -e /etc/ssh/sshd_config.d/rtruell ]]; then  # and the file with my configuration is already in it
    print_result $? "'/etc/ssh/sshd_config.d/rtruell' exists"
  else
    sudo printf "%s\n" "Port 22000  # change the port in an attempt to foil crackers" >>/etc/ssh/sshd_config.d/rtruell  # create the file '/etc/ssh/sshd_config.d/rtruell
    print_result $? "Created 'rtruell' in '/etc/ssh/sshd_config.d'"
    sudo chmod 440 /etc/ssh/sshd_config.d/rtruell  # set its permissions
    print_result $? "Changed permissions for '/etc/ssh/sshd_config.d/rtruell'"
  fi
else
  # the directory doesn't exist, so create it, set its permissions, create the file '/etc/ssh/sshd_config.d/rtruell', and set its permissions
  sudo mkdir /etc/ssh/sshd_config.d
  print_result $? "Created '/etc/ssh/sshd_config.d'"
  sudo chmod 755 /etc/ssh/sshd_config.d
  print_result $? "Changed permissions for '/etc/ssh/sshd_config.d'"
  sudo printf "%s\n" "Port 22000  # change the port in an attempt to foil crackers" >>/etc/ssh/sshd_config.d/rtruell
  print_result $? "Created 'rtruell' in '/etc/ssh/sshd_config.d'"
  sudo chmod 440 /etc/ssh/sshd_config.d/rtruell
  print_result $? "Changed permissions for '/etc/ssh/sshd_config.d/rtruell'"
fi

# change the timeout value in 'grub'
sudo sed -E 's/(GRUB_TIMEOUT=).*/\110/' -i /etc/default/grub  # change the timeout to 10 seconds, regardless of what it was
print_result $? "Changed the timeout value for 'grub'"
sudo update-grub  # update grub so the new value takes effect
print_result $? "Updated 'grub'"

# get the machine type
machinetype=$(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f3)
print_result $? "Machine type is: ${machinetype}"

# commands dependent on the type of machine being installed
case "${machinetype}" in
      Laptop)
              # allow the laptop lid to be closed enough to blank the display
              # without putting the computer into 'sleep' mode
              sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
              print_result $? "Closing lid won't put computer into 'sleep' mode"
              sudo systemctl restart systemd-logind.service  # restart the service so the changes take effect immediately
              print_result $? "Service restarted"

              # if installing on the Acer laptop
              if [[ $(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f3) == "Acer" ]]; then
                # configure 'apt' so it can find the drivers for the wi-fi card,
                # and then install them
                sudo cp /etc/apt/sources.list /etc/apt/sources.list.orig  # back up 'sources.list', just in case
                print_result $? "Backed up 'sources.list'"
                sudo sed -E 's/(^deb.*&)/\1 contrib non-free/' -i /etc/apt/sources.list  # append ' contrib non-free' to each repository line
                print_result $? "Appended ' contrib non-free' to the repository lines"
                sudo apt update  # update 'apt' so it sees the contents of the new repositories
                print_result $? "Updated 'apt' to get info from the new repositories"
                sudo apt install firmware-b43-installer  # install the wi-fi drivers
                print_result $? "Installed drivers for the wi-fi card"

                # 64-bit Debian - and *only* 64-bit Debian - for some odd reason
                # won't boot on the Acer laptop without blacklisting the
                # 'acer_wmi' module.  so, check to see if running 64-bit Debian
                # and if so, blacklist the module
                if [[ $(getconf LONG_BIT) == 64 ]] && [[ $(lsb_release -i -s) == "Debian" ]]; then
                  sudo printf '%s\n' "blacklist acer_wmi" >>/etc/modprobe.d/blacklist-acer_wmi.conf
                  print_result $? "Created 'blacklist-acer_wmi.conf' in '/etc/modprobe.d'"
                  sudo chmod 544 /etc/modprobe.d/blacklist-acer_wmi.conf
                  print_result $? "Changed permissions for '/etc/modprobe.d/blacklist-acer_wmi.conf'"
                fi
              fi
              ;;
  Virtualbox)
              # if the Guest Additions aren't installed, install them so the
              # window can be maximized, and to have bi-directional sharing of
              # folders and the clipboard
              if [[ ! $(lsmod | grep vboxguest) ]]; then
                printf '%s\n' "Go to the 'Devices' menu and select 'Insert Guest Additions CD image...'"  # prompt to insert the CD image
                read -n1 -r -p "Press any key once that's done."
                sudo mount /dev/cdrom  # mount the CD image
                print_result $? "CD image mounted"
                sudo sh /media/cdrom/VBoxLinuxAdditions.run  # run the installer
                print_result $? "Installed Guest Additions"
                sudo umount /dev/cdrom  # unmount the CD image
                print_result $? "CD image unmounted"
              else
                print_result 0 "Guest Additions installed"
              fi
              printf '\n%s\n' "Don't forget to maximize the screen after rebooting!"

              # if 'rtruell' isn't in the group 'vboxsf', add him to be able
              # to access shared folders
              if [[ ! $(groups | grep vboxsf) ]]; then
                sudo adduser rtruell vboxsf
                print_result $? "Added 'rtruell' to group 'vboxsf'"
              else
                print_result 0 "'rtruell' in group 'vboxsf'"
              fi
              ;;
           *) ;;

# install, update and check Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
print_result $? "Installed Homebrew"
brew update
print_result $? "Updated Homebrew"
brew doctor
print_result $? "Checked Homebrew"

# export some environment variables for Homebrew
export HOMEBREW_EDITOR="${EDITOR}"  # use the system editor to edit Homebrew stuff
export BREW_PREFIX=$(brew --prefix)  # store Homebrew's installation directory so I don't have to keep issuing the command
print_result 0 "Exported Homebrew environment variables"

## install all the things
#echo "About to install the .Brewfile contents...this could take a while!!"
#brew bundle --global
#print_result $? "Installed desired formula"

# remove outdated versions from the cellar
brew cleanup
print_result $? "Cleaned up Homebrew"

## switch to using brew-installed bash as default shell
#if [[ -x "${BREW_PREFIX}/bin/bash" ]]; then
#  if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then  # if the new bash isn't already in the list of shell programs
#    sudo printf '%s\n' "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells  # add it
#    print_result $? "Updated '/etc/shell' with the just-installed version of bash"
#  fi
#  chsh -s "${BREW_PREFIX}/bin/bash"  # change the shell to the new bash
#  print_result $? "Changed the shell to the new version of bash: $BASH_VERSION (should be 4+)"  # should be 4+ not the old 3.2.X
#else
#  print_result 1 "bash not installed properly by Homebrew"
#fi

# add the repository for Webmin to 'apt'
wget -q https://www.webmin.com/jcameron-key.asc -O- | apt-key add -
print_result $? "Added GPG key for the Webmin repository"
sudo printf '\n%s\n%s\n%s\n' " " "# Repository for Webmin" "deb https://download.webmin.com/download/repository sarge contrib" >>/etc/apt/sources.list
print_result $? "Added the Webmin repository to 'sources.list'"

# add the repository for Sublime Text/Merge to 'apt'
wget -q https://download.sublimetext.com/sublimehq-pub.gpg -O- | apt-key add -
print_result $? "Added GPG key for the Sublime Text/Merge repository"
sudo printf '\n%s\n%s\n%s\n' " " "# Repository for Sublime Text/Merge" "deb https://download.sublimetext.com/ apt/stable/" >>/etc/apt/sources.list
print_result $? "Added the Sublime Text/Merge repository to 'sources.list'"

# since secure repositories were added to 'apt', install 'apt-transport-https'
sudo apt install apt-transport-https
print_result $? "Installed 'apt-transport-https'"

# update && upgrade apt
sudo apt update
sudo apt upgrade

#apt install \
#  `# read-write NTFS driver for Linux` \
#  ntfs-3g \
#  `# do not delete main-system-dirs` \
#  safe-rm \
#  `# default for many other things` \
#  tmux \
#  build-essential \
#  autoconf \
#  make \
#  cmake \
#  mktemp \
#  dialog \
#  hardinfo \
#  synaptic \
#  samba \
#  netselect-apt \
#  cifs-utils \
#  jre \
#  firefox \
#  gdebi-core \
#  sublime-text \
#  sublime-merge \
#  webmin \
#  firmware-misc-nonfree \
#  amd64-microcode \
#  gcc \
#  inxi \
#  dmidecode \  # might be installed automatically
#  `# unzip, unrar etc.` \
#  cabextract \
#  zip \
#  unzip \
#  rar \
#  unrar \
#  tar \
#  pigz \
#  p7zip \
#  p7zip-full \
#  p7zip-rar \
#  unace \
#  bzip2 \
#  gzip \
#  xz-utils \
#  advancecomp \
#  `# optimize image-size` \
#  gifsicle \
#  optipng \
#  pngcrush \
#  pngnq \
#  pngquant \
#  jpegoptim \
#  libjpeg-progs \
#  jhead \
#  `# utilities` \
#  coreutils  \
#  findutils  \
#  moreutils  \
#  `# fast alternative to dpkg -L and dpkg -S` \
#  dlocate \
#  `# quickly find files on the filesystem based on their name` \
#  mlocate \
#  locales \
#  `# removing unneeded localizations` \
#  localepurge \
#  sysstat \
#  tcpdump \
#  colordiff \
#  moreutils \
#  atop \
#  ack-grep \
#  ngrep \
#  `# interactive processes viewer` \
#  htop \
#  `# mysql processes viewer` \
#  mytop \
#  `# interactive I/O viewer` \
#  iotop \
#  tree \
#  `# disk usage viewer` \
#  ncdu \
#  rsync \
#  whois \
#  vim \
#  csstidy \
#  recode \
#  exuberant-ctags \
#  `# GNU bash` \
#  bash \
#  bash-completion \
#  `# command line clipboard` \
#  xclip \
#  `# more colors in the shell` \
#  grc \
#  `# fonts also "non-free"-fonts` \
#  `# -- you need "multiverse" || "non-free" sources in your "source.list" -- ` \
#  fontconfig \
#  ttf-freefont \
#  ttf-mscorefonts-installer \
#  ttf-bitstream-vera \
#  ttf-dejavu \
#  ttf-liberation \
#  ttf-linux-libertine \
#  ttf-larabie-deco \
#  ttf-larabie-straight \
#  ttf-larabie-uncommon \
#  ttf-liberation \
#  xfonts-jmk \
#  `# trace everything` \
#  strace \
#  `# get files from web` \
#  wget \
#  w3m \
#  `# repo-tools`\
#  git \
#  subversion \
#  mercurial \
#  `# usefull tools` \
#  boxes \
#  fortune \
#  sl \
#  groff \
#  id3tool \
#  jq \
#  telnet \
#  sshd \
#  thefuck \
#  k4dirstat \
#  network-manager-openconnect \
#  shutter \
#  openjdk \
#  virtualbox \
#  vlc \
#  zenmap \
#  ruby-full \
#  imagemagick \
#  lynx \
#  nmap \
#  pv \
#  ucspi-tcp \
#  xpdf \
#  sqlite3 \
#  perl \
#  python \
#  python-pip \
#  python3-pip \
#  python-dev \
#  python3-dev \
#  python3-setuptools \
#  `# install python-pygments for json print` \
#  python-pygments

#echo "install php-5-extensions ..."
#
#apt install \
#  php5-cli \
#  php5-mysql \
#  php5-curl \
#  php5-gd \
#  php5-intl \
#  php-pear \
#  php5-imagick \
#  php5-imap \
#  php5-mcrypt \
#  php5-memcached \
#  php5-ming \
#  php5-ps \
#  php5-pspell \
#  php5-recode \
#  php5-snmp \
#  php5-sqlite \
#  php5-tidy \
#  php5-xmlrpc \
#  php5-xsl \
#  php5-xdebug \
#  php5-apcu \
#  php5-geoip
#
#php5enmod json
#php5enmod mcrypt
#php5enmod curl
#php5enmod mysql
#php5enmod gd
#php5enmod imagick
#php5enmod apcu

#echo -e "\033[1;32mCopying Beyond Compare files to 'root'\033[m\n"
#cp bc* /root
#cp BC* /root
#cd /root
#echo -e "\033[1;32mCopying Beyond Compare files to 'rtruell'\033[m\n"
#for filename in BC*
#do
#  chmod 644 ${filename}
#  cp ${filename} /home/rtruell
#  chown rtruell:rtruell /home/rtruell/${filename}
#done
#echo -e "\033[1;32mInstalling Beyond Compare\033[m\n"
#gdebi *.deb
#echo -e "\033[1;32mAdding 'rtruell' and 'root' to samba so I can access files from other computers\033[m\n"
#sudo smbpasswd -a rtruell
#sudo smbpasswd -a root
#echo -e "\033[1;32mCreating the mount points for 'fileserver' and 'backupserver'\033[m\n"
#sudo mkdir -p /network/fileserver
#sudo mkdir -p /network/backupserver
#echo -e "\033[1;32mAdding mount commands for network shares to '/etc/fstab'\033[m\n"
#cp /etc/fstab /etc/fstab.orig
#echo " " >>/etc/fstab
#echo "# Mount network shares" >>/etc/fstab
#echo "//fileserver/data /network/fileserver cifs auto,credentials=/root/.credentials,iocharset=utf8 0 0" >>/etc/fstab
#echo "//backupserver/backups /network/backupserver cifs auto,credentials=/root/.credentials,iocharset=utf8 0 0" >>/etc/fstab

# update-locate-db
updatedb -v
print_result $? "Locate database updated"
