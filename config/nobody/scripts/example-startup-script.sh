#!/bin/bash

# Example script showing how to install packages from AOR/AUR.

# aor packages
###

# Define AOR (Arch Official Repository) packages you want to install at startup.
# Go to the following URL for a searchable list of packages:- https://archlinux.org/packages/
pacman_packages=""

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# aur packages
###

# Define AUR (Arch User Repository) packages you want to install at startup.
# Go to the following URL for a searchable list of packages:- https://aur.archlinux.org/packages/
aur_packages=""

# install compiled packages using helper 'yay'
if [[ ! -z "${aur_packages}" ]]; then
	source '/usr/local/bin/aur.sh'
fi
