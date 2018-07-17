#!/bin/bash

cpus=$(cpufreq-info |grep -E "CPU [0-9]+:$" | cut -f 3 -d " "|cut -f 1 -d ":")

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. $DIR/util.sh

function cpuperf {
  echo "CPU performance"
  for cpu in $cpus; do
    execute cpufreq-set -c $cpu -d 3500000 -u 3500000
    execute cpufreq-set -c $cpu -g performance
  done
}

function cpusave {
  echo "CPU powersave"
  for cpu in $cpus; do
    execute cpufreq-set -c $cpu -d 400000 -u 3500000
    execute cpufreq-set -c $cpu -g powersave
  done
}


function lower_all {
  lower "Battle.net.exe"
  lower "Battle.net Help"
  lower "Agent.exe"
}

function killproc {
  local procname="$1"
  local pid=$(ps -ef|grep -E "$procname" |grep -v grep|awk '{print $2}' 2> /dev/null)
  if [ "x" != "x$pid" ] ; then
    ech "Killing $CYAN$procname$NO_COLOR"
    execute kill $pid
  else
    ech "No matching process for $CYAN$procname$NO_COLOR"
  fi
}

function killbnet {
  killproc "Battle.net.exe"
  killproc "Battle.net Help"
  killproc "Agent.exe"
}


function cleanup {
  if [ "xDONE" == "x$CLEANUP" ] ; then
    exit 0
  fi
  CLEANUP=DONE

  set +e

  ech "Cleaning up"

  tweak_key_repeat
  cpusave

  killbnet
  killproc "SC2.*.exe"
  killproc "wineserver"
  killproc "C:\\\\windows\\\\system32"

  ech "Done"
  exit 0
}

trap "cleanup" SIGINT SIGTERM EXIT

function tweak_key_repeat {
  # This works on X but not on wayland
  local focused=$(xdotool getwindowfocus getwindowpid 2>/dev/null)

  # Workaround for wayland - enable if process is running
  #local focused=$1
  if [ "x$focused" == "x$pid" ] ; then
    if [ "$fast_repeat" != "enabled" ] ; then
      fast_repeat="enabled"

      # Speed up key repeat for faster warpins
      execute xset r rate 200 200

      # Start with a clean slate
      execute xkbset perkeyrepeat 0000000000000000000000000000000000000000000000000000000000000000

      # (find keycodes to toggle with 'xev')
      # enable repeat for 'W' (warpin)
      execute xkbset repeatkeys 25
      # enable repeat for 'G' (convert to warpgate)
      execute xkbset repeatkeys 42
      # enable repeat for backspace
      execute xkbset repeatkeys 22

    fi
  else
    if [ "$fast_repeat" != "disabled" ] ; then
      fast_repeat="disabled"
      ech "Restoring keyboard repeat"
      execute xset r rate 400 50
      execute xkbset perkeyrepeat 00ffffffdffffbbffadfffefffedffff9ffffffffffffffffff7ffffffffffff
    fi
  fi
}

function startbnet {
  local bnetpid=`getpid Battle.net.exe`
  if [ "x" == "x$bnetpid" ] ; then
    ech "Launching Battle.net"
    WINEDEBUG=-all wine ~/.wine/drive_c/Program\ Files/Blizzard\ App/Battle.net.exe &>/dev/null &
  fi
}

function optimize {
  local pid=$1
  shift

  local aff=$1
  shift

  local game="$1"
  shift

  local color="$1"
  shift

  ech "$CYAN$game$NO_COLOR running ($LIGHT_CYAN$pid$NO_COLOR)"

  cpuperf
  killbnet

  echo -e "Waiting for $CYAN$game$NO_COLOR ($LIGHT_CYAN$pid$NO_COLOR) to exit..."
  while ps --pid $pid > /dev/null; do
    lower_all
    tweak_key_repeat $pid
    sleep 5
  done
  echo
  startbnet

  cpusave

  ech "$CYAN$game$NO_COLOR has exited"

  echo
}

function main {
  startbnet
  local fast_repeat=""
  while true; do
    ech "Waiting for SC2 to start..."
    while true; do
      lower_all
      killproc "winedbg" # SystemSurvey always crashes, which leads to winedbg starting
      disable_mouse_acceleration

      local pid=`getpid SC2.exe`
      if [ "x" != "x$pid" ] ; then
        echo
        optimize $pid 2,3 "Starcraft 2" "#ff2200"
        startbnet
        break
      fi

      tweak_key_repeat _disable_
      sleep 5
    done
  done
}

main


