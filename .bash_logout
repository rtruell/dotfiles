# ~/.bash_logout: executed by bash(1) when login shell exits.

# when leaving the console clear the screen to increase privacy

cd ${DOTFILES}
compname=$(hostname -s)
git add .bash_history-${compname}
git commit -m "Updated .bash_history file for ${compname}."
git push origin main
read -n1 -r -p "Press any key to continue..."

if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear ] && /usr/bin/clear
fi
