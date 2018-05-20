#!/bin/bash
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. $DIR/util.sh

cd "/home/krka/.wine/drive_c/Program Files/Warcraft III"
WINEDEBUG=-all wine "Warcraft III Launcher.exe"

