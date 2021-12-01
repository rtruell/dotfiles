#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# Linux-only stuff.  abort if not Linux.
if [[ "$(uname)" != "Linux" ]]; then printf '%s\n' "This script is to be run only on Linux"; exit 1; fi

# have the output of the script both on the screen and in a file...just in case
# there are errors that need to be checked later
exec > >(tee -i ~/installlog.txt) 2>&1

# some functions are needed to set things up, so load them
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

# get the users login name
username=`echo ${USER}`
print_result $? "User doing the install is '${username}'"

# make it so the user can use 'sudo'.  the code that was in here suddenly
# stopped working, so it was removed and put into its own script file.  it's
# actually better that way...'su -c' can only run "one" command at a time, so
# if doing multiple things is required, either there has to be multiple 'su -c'
# lines and type the password each time, or there has to be one humongous
# command line.  using an external script, the passord only has to be typed
# once, but each command can be on its own line, making it easier to follow
# what's being done and to debug problems
su -c 'source ./sudo.sh'
print_result $? "Configured 'sudo' access"

# install some packages, if necessary, so everything in the rest of this script
# can be done
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
  if [[ ! $(apt list --installed 2>/dev/null | grep "^${i}") ]]; then  # if the package isn't already installed
    yes | sudo apt install "${i}"  # install it, automatically answering 'yes' to any prompts
    print_result $? "Installed ${i}"
  else  # the package is already installed
    print_result 0 "${i} already installed"
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
sudo mount -t cifs -o user=rtruell //fileserver/data ~/mountpoint  # ... and mount it.  don't forget to change the user name as necessary
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

  # install config files for Beyond Compare
  if [[ ! -d ~/.config/bcompare ]]; then  # if '.config/bcompare' doesn't exist
    mkdir ~/.config/bcompare  # create it
    print_result $? "Created '.config/bcompare'"
    chmod 755 ~/.config/bcompare  # and set its permissions
    print_result $? "Set permissions for '.config/bcompare'"
  else
    print_result 0 "'.config/bcompare' exists"
  fi
  cp -a BC4Key.txt ~/.config/bcompare
  print_result $? "Copied the Beyond Compare key file to '~/.config/bcompare'"
  chmod 600 ~/.config/bcompare/BC4Key.txt
  print_result $? "Set permissions for the Beyond Compare key file"
  cp -a BCSettings-lin*.bcpkg ~
  print_result $? "Copied the Beyond Compare settings file"
  chmod 600 ~/BCSettings-lin*.bcpkg
  print_result $? "Set permissions for the Beyond Compare settings file"

  # copy programs that aren't available in 'apt' or 'Homebrew'.  the programs
  # must be previously downloaded and located in '//fileserver/data/Downloads/Linux/InUse/Installed'
  declare -a programs=(
    "bcompare*"
  )
  i=""
  programdir="~/mountpoint/Downloads/Linux/InUse/Installed"  # the directory containing the programs to be copied
  programtmp="/tmp/programs"
  if [[ ! -d "${programtmp}" ]]; then
    mkdir "${programtmp}"
    print_result $? "Created '"${programtmp}"'"
  else
    print_result 0 "'"${programtmp}"' exists"
  fi
  for i in ${programs[@]}; do  # loop through the array of programs
    cp -a "${programdir}/${i}" "${programtmp}"  # copy the program to '/tmp'
    print_result $? "Copied ${i}"
  done
  cd "${currdir}"  # change back to where we were
  print_result $? "Changed back to '${currdir}'"

  # install any '.deb' programs, since they're easy to do in a script
  shopt -s dotglob
  shopt -s nullglob
  filenames=("${programtmp}/*.deb")  # get a list of all the '.deb' files in the '/tmp/programs' directory into an array.  filenames are of the format "/tmp/programs/<program>.deb"
  shopt -u nullglob
  for i in "${filenames[@]}"; do  # loop through all the '.deb' files that were found
    if [[ ! $(apt list --installed 2>/dev/null | grep "^`echo "${i}" | tr '[:punct:][:digit:]' ' ' | cut -d' ' -f4`" >/dev/null) ]]; then  # if the program isn't already installed
      yes | sudo apt install "${i}"  # install it, automatically answering 'yes' to any prompts
      print_result $? "Installed ${i}"
    else  # the package is already installed
      print_result 0 "${i} already installed"
    fi
  done

  # done with the NAS, so try to unmount it
  sudo umount ~/mountpoint  # unmount the NAS
  print_result $? "Unmounted NAS"
else
  print_result ${retcode} "Mounting NAS failed...sensitive files/directories must be copied manually"
fi
rmdir ~/mountpoint  # remove the mountpoint
print_result $? "Removed mount point"

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
    sudo chmod 440 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
    print_result $? "Changed permissions for '/etc/ssh/sshd_config.d/port.conf'"
  fi
else
  sudo mkdir /etc/ssh/sshd_config.d  # the directory doesn't exist, so create it
  print_result $? "Created '/etc/ssh/sshd_config.d'"
  sudo chmod 755 /etc/ssh/sshd_config.d  # change its' permissions
  print_result $? "Changed permissions for '/etc/ssh/sshd_config.d'"
  printf "Port 22000  # change the port in an attempt to foil crackers\n" | sudo tee /etc/ssh/sshd_config.d/port.conf >/dev/null  # create the file with the port number change
  print_result $? "Created '/etc/ssh/sshd_config.d/port.conf'"
  sudo chmod 440 /etc/ssh/sshd_config.d/port.conf  # and set its permissions
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
              # allow the laptop lid to be closed enough to blank the display
              # without putting the computer into 'sleep' mode
              sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
              print_result $? "Closing lid won't put computer into 'sleep' mode"
              sudo systemctl restart systemd-logind.service  # restart the service so the changes take effect immediately
              print_result $? "Service restarted"

              # if installing on the Acer laptop
              if [[ $(inxi -M | grep -i type | tr -s ' ' | cut -d' ' -f5) == "Acer" ]]; then
                # configure 'apt' so it can find the drivers for the wi-fi card,
                # and then install them
                sudo cp /etc/apt/sources.list /etc/apt/sources.list.orig  # back up 'sources.list', just in case
                print_result $? "Backed up 'sources.list'"
                sudo sed -E 's/(^deb.*$)/\1 contrib non-free/' -i /etc/apt/sources.list  # append ' contrib non-free' to each repository line
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

              # if the user is not in the group 'vboxsf', add them so they're
              # able to access shared folders
              if [[ ! $(groups | grep vboxsf) ]]; then
                sudo adduser "${username}" vboxsf
                print_result $? "Added '${username}' to group 'vboxsf'"
              else
                print_result 0 "'${username}' is already in group 'vboxsf'"
              fi
              ;;
           *) ;;
esac

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"  # install Homebrew
print_result $? "Installed Homebrew"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"  # add its directories to the PATH temporarily (this is done permanently in the '.path' dotfile)
print_result $? "Added Homebrew directories to the PATH"
brew update  # update it
print_result $? "Updated Homebrew"
brew doctor  # check it
print_result $? "Checked Homebrew"

# export some environment variables for Homebrew
export HOMEBREW_EDITOR="${EDITOR}"  # use the system editor to edit Homebrew stuff
export BREW_PREFIX=$(brew --prefix)  # store Homebrew's installation directory so I don't have to keep issuing the command
print_result $? "Exported Homebrew environment variables"

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
#  print_result $? "Changed the shell to the new version of bash: $BASH_VERSION (should be 4+)"  # should be 4+ not the old 3.2.x
#else
#  print_result 1 "bash not installed properly by Homebrew"
#fi

# add the repository for Webmin to 'apt'
sudo ~/bin/add-apt-key https://download.webmin.com/jcameron-key.asc webmin "deb https://download.webmin.com/download/repository sarge contrib"
print_result $? "Added the Webmin repository to 'apt'"

# add the repository for Sublime Text/Merge to 'apt'
sudo ~/bin/add-apt-key https://download.sublimetext.com/sublimehq-pub.gpg sublimehq "deb https://download.sublimetext.com/ apt/stable/"
print_result $? "Added the Sublime Text/Merge repository to 'apt'"

# since secure repositories were added to 'apt', install 'apt-transport-https'
sudo apt install apt-transport-https
print_result $? "Installed 'apt-transport-https'"

# update apt to pick up the new repositories, and then do an upgrade
sudo apt update
print_result $? "apt updated"
sudo apt upgrade
print_result $? "apt upgraded"

apt install samba
print_result $? "samba installed"
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

# Add the user to samba so they can access files from other computers
sudo smbpasswd -a "${username}"
print_result $? "Added '${username}' to samba"

# Create mount points for the 'data' and 'backups' directories on the NAS
sudo mkdir -p /nas/data
print_result $? "Created '/nas/data'"
sudo mkdir -p /nas/backups
print_result $? "Created '/nas/backups'"

# Adding mount commands for the NAS shares to '/etc/fstab'
sudo cp /etc/fstab /etc/fstab.orig
print_result $? "Backed up '/etc/fstab'"
printf '%s\n' " " | sudo tee -a /etc/fstab >/dev/null
print_result $? "Added separator line to '/etc/fstab'"
printf '%s\n' "# Mount NAS shares" | sudo tee -a /etc/fstab >/dev/null
print_result $? "Added comment explaining the new section to '/etc/fstab'"
printf '%s\n' "//fileserver/data /nas/data cifs auto,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null
print_result $? "Added mount command for 'data' directory on NAS to '/etc/fstab'"
printf '%s\n' "//fileserver/backups /nas/backups cifs auto,credentials=${HOME}/.credentials,iocharset=utf8 0 0" | sudo tee -a /etc/fstab >/dev/null
print_result $? "Added mount command for 'backups' directory on NAS to '/etc/fstab'"

# update the locate database
updatedb
print_result $? "updated the 'locate' database"
