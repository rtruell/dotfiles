#!/usr/bin/env bash
StartDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${StartDir}"

# Debian-only stuff. Abort if not Debian.
if [[ "${SYSTEM_TYPE}" != "Linux" ]]; then return 1; fi

# get the Debian distro release name, eg. "buster"
release_name=$(lsb_release -c | awk '{print $2}')

# check to see if the Debian desktop is installed
function is_debian_desktop() {
  dpkg -l desktop-base >/dev/null 2>&1 || return 1
}

# Test if this script was run via the "dotfiles" bin script (vs. via curl/wget)
function is_dotfiles_bin() {
  [[ "$(basename $0 2>/dev/null)" == dotfiles ]] || return 1
}

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  echo "Plese use sudo or su"
  exit 1
fi

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

printf "\033[0m\n"
printf " #    # ###### #    #       # #    #  ####  #####   ##   #      #        ### ###\n"
printf " ##   # #      #    #       # ##   # #        #    #  #  #      #        ### ###\n"
printf " # #  # #####  #    #       # # #  #  ####    #   #    # #      #        ### ###\n"
printf " #  # # #      # ## #       # #  # #      #   #   ###### #      #        ### ###\n"
printf " #   ## #      ##  ##       # #   ## #    #   #   #    # #      #               \n"
printf " #    # ###### #    #       # #    #  ####    #   #    # ###### ######   ### ###\n"
printf "\n"
unset colours z i r v

# Check if /usr/bin/sudo and /bin/bash exist. if not, try to find them and suggest a symlink
if [[ ! -f /usr/bin/sudo ]]; then
  if findcommand sudo &>/dev/null; then
    printf -- '%s\n' "/usr/bin/sudo not found.  Please run 'sudo ln -s $(findcommand sudo) /usr/bin/sudo'"
  else
    printf -- '%s\n' "/usr/bin/sudo not found, and I couldn't find 'sudo' in '$PATH'"
  fi
  exit
fi
if [[ ! -f /bin/bash ]]; then
  if findcommand bash &>/dev/null; then
    printf -- '%s\n' "/bin/bash not found.  Please run 'sudo ln -s $(findcommand bash) /bin/bash'"
  else
    printf -- '%s\n' "/bin/bash not found, and I couldn't find 'bash' in '$PATH'"
  fi
  exit
fi

# use aptitude in the next steps ...
if [ \! -f $(whereis aptitude | cut -f 2 -d ' ') ] ; then
  apt-get install aptitude
fi

# update && upgrade
aptitude update
aptitude upgrade

aptitude install \
  `# read-write NTFS driver for Linux` \
  ntfs-3g \
  `# do not delete main-system-dirs` \
  safe-rm \
  `# default for many other things` \
  tmux \
  build-essential \
  autoconf \
  make \
  cmake \
  mktemp \
  dialog \
  `# unzip, unrar etc.` \
  cabextract \
  zip \
  unzip \
  rar \
  unrar \
  tar \
  pigz \
  p7zip \
  p7zip-full \
  p7zip-rar \
  unace \
  bzip2 \
  gzip \
  xz-utils \
  advancecomp \
  `# optimize image-size` \
  gifsicle \
  optipng \
  pngcrush \
  pngnq \
  pngquant \
  jpegoptim \
  libjpeg-progs \
  jhead \
  `# utilities` \
  coreutils  \
  findutils  \
  `# fast alternative to dpkg -L and dpkg -S` \
  dlocate \
  `# quickly find files on the filesystem based on their name` \
  mlocate \
  locales \
  `# removing unneeded localizations` \
  localepurge \
  sysstat \
  tcpdump \
  colordiff \
  moreutils \
  atop \
  ack-grep \
  ngrep \
  `# interactive processes viewer` \
  htop \
  `# mysql processes viewer` \
  mytop \
  `# interactive I/O viewer` \
  iotop \
  tree \
  `# disk usage viewer` \
  ncdu \
  rsync \
  whois \
  vim \
  csstidy \
  recode \
  exuberant-ctags \
  `# GNU bash` \
  bash \
  bash-completion \
  `# command line clipboard` \
  xclip \
  `# more colors in the shell` \
  grc \
  `# fonts also "non-free"-fonts` \
  `# -- you need "multiverse" || "non-free" sources in your "source.list" -- ` \
  fontconfig \
  ttf-freefont \
  ttf-mscorefonts-installer \
  ttf-bitstream-vera \
  ttf-dejavu \
  ttf-liberation \
  ttf-linux-libertine \
  ttf-larabie-deco \
  ttf-larabie-straight \
  ttf-larabie-uncommon \
  ttf-liberation \
  xfonts-jmk \
  `# trace everything` \
  strace \
  `# get files from web` \
  wget \
  curl \
  w3m \
  `# repo-tools`\
  git \
  subversion \
  mercurial \
  `# usefull tools` \
  boxes \
  fortune \
  sl \
  groff \
  id3tool \
  jq \
  telnet \
  thefuck \
  k4dirstat \
  network-manager-openconnect \
  shutter \
  openjdk \
  virtualbox \
  vlc \
  zenmap \
  nodejs \
  npm \
  ruby-full \
  imagemagick \
  lynx \
  nmap \
  pv \
  ucspi-tcp \
  xpdf \
  sqlite3 \
  perl \
  python \
  python-pip \
  python3-pip \
  python-dev \
  python3-dev \
  python3-setuptools \
  `# install python-pygments for json print` \
  python-pygments

#echo "install php-5-extensions ..."
#
#aptitude install \
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

# clean downloaded and already installed packages
aptitude -v clean

# update-locate-db
echo "update-locate-db ..."
updatedb -v

##############################################################################################################
### symlinks to link dotfiles into ~/
###

#   move git credentials into ~/.gitconfig.local    	http://stackoverflow.com/a/13615531/89484
#   now .gitconfig can be shared across all machines and only the .local changes

# symlink it up!
source ./symlink.sh

# add manual symlink for .ssh/config and probably .config/fish

###
##############################################################################################################

# Ensure .ssh dir sanity
#mkdir -p ~/.ssh
#chmod 700 ~/.ssh
#touch ~/.ssh/authorized_keys
#chmod 600 ~/.ssh/authorized_keys

# Local github files
#touch ~/.gitconfig.local
#chmod 600 ~/.gitconfig.local
