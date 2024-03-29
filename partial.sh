#!/usr/bin/env bash

# when it all went to hell and you want a familiar environment in which to fix
# things, clone the 'dotfiles' repository and then run this.  it loads some
# functions and makes them available outside this script, symlinks the
# dotfiles, gives 'sudo' permissions to 'rtruell', sets the RTC to local time
# so I don't have to keep futzing with the BIOS to reset the time properly
# every time I reboot, and installs 'liquidprompt' to give a nice prompt.

source ./.functions/answer_is_y.function
source ./.functions/apt_package_installer.function
source ./.functions/execute_command.function
source ./.functions/01#findcommand.function
source ./.functions/print_error.function
source ./.functions/print_info.function
source ./.functions/print_result.function
source ./.functions/print_success.function
source ./.functions/print_warn.function
source ./.functions/symlink_array_files.function
source ./.functions/symlink_single_file.function
source ./.functions/trim.function

export -f findcommand
export -f answer_is_y
export -f apt_package_installer
export -f execute_command
export -f print_error
export -f print_info
export -f print_result
export -f print_success
export -f print_warn
export -f symlink_array_files
export -f symlink_single_file
export -f trim

computername=$(hostname -s)
source ./symlink.sh
su -c 'source ./sudo.sh'
sudo timedatectl set-local-rtc 1
print_result "${?}" "RTC set to local time"
apt_package_installer "liquidprompt"

print_info "All done.  Now, exit the shell and then re-open it.\n"
