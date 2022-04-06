#!/bin/zsh
#
# Author:   Timothy J. Luoma
# Email:    luomat at gmail dot com
# Date:     2011-07-20
#
# Purpose:  install a pkg
#
# URL:      https://github.com/tjluoma/pkginstall

# MAKE_PUBLIC:YES

# Changelog
# 2022-03-14  Rick Truell
#
# - fixed up the spacing and indentation

# filename of the script
NAME="$0:t"

# We're going to make a temp file, but we'll make sure no one else can read it
umask 077

REBOOT=no
AUTO_REBOOT=no
ERROR=0

if [ "$1" = "-r" ]; then
  # if you call `pkginstall.sh -r` it will automatically reboot after completion
  # BUT only if one of the installation pkgs requested a reboot
  AUTO_REBOOT=yes
  shift
elif [ "$1" = "-R" ]; then
  # if you call `pkginstall.sh -R` it will automatically reboot 1 minute after completion
  # REGARDLESS of whether any packages requested a reboot
  AUTO_REBOOT=yes
  REBOOT=yes
  shift
fi

for FILE in $@; do
  if [[ -r "$FILE" ]]; then
    # $FILE exists and is readable

    # zsh - get extension
    EXT="$FILE:e"

    if [ "$EXT" = "pkg" -o "$EXT" = "mpkg" ]; then
      # zsh - get filename without `dirname` or extension.
      #     i.e. /path/to/foo.bat becomes "foo"
      SHORT="$FILE:r:t"

      # Create a log for each package
      # LOGNAME is username
      # NAME:r is the name of this script without path
      # $SHORT is package name without path or extension
      LOG="/tmp/$LOGNAME.$NAME:r.$SHORT.log"

      # tell the user what we are doing
      # especially why they might be asked for their password
      MSG="$NAME: Installing $FILE\n\tLogging to $LOG\n(Note: sudo may ask for your administrator password)"

    else
      # if the file extension isn't pkg or mpkg then this isn't a package
      # don't try to install it
      echo "$FILE is not a package, \$EXT is $EXT."

      # we don't exit immediately because we might be able to install other packages
      ERROR=1
    fi # file extension check
  else
    echo "$NAME: $FILE does not exist or isn't readable"
    # we don't exit immediately because we might be able to install other packages
    ERROR=1
  fi
  printf '%s\n' "name is >${NAME}<"
  printf '%s\n' "file is >${FILE}<"
  printf '%s\n' "ext is >${EXT}<"
  printf '%s\n' "short is >${SHORT}<"
  printf '%s\n' "log is >${LOG}<"
  printf '%s\n' "msg is >${MSG}<"
done
