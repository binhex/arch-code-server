#!/bin/bash

# Example script showing how to install packages from AOR/AUR.

# aor packages
###

# Define AOR (Arch Official Repository) packages you want to install at startup.
# Go to the following URL for a list of available packages:- https://archlinux.org/packages/
# If you want to install more than one package then please user a space as a separator.
# Example: To install docker and Java Runtime 11 you would specify:-
# pacman_packages="jre11-openjdk-headless"
pacman_packages=""

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# aur packages
###

# Define AUR (Arch User Repository) packages you want to install at startup.
# Go to the following URL for a list of available packages:- https://aur.archlinux.org/packages/
# If you want to install more than one package then please user a space as a separator.
# Example: To install docker and Java Runtime 11 you would specify:-
# aur_packages="powershell"
aur_packages=""

# install compiled packages using helper 'yay'
if [[ ! -z "${aur_packages}" ]]; then
	source '/usr/local/bin/aur.sh'
fi
