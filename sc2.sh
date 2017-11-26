#!/bin/bash

GREEN="\033[1;32m"
GRAY="\033[1;30m"
LIGHT_GRAY="\033[0;37m"
CYAN="\033[0;36m"
LIGHT_CYAN="\033[1;36m"
NO_COLOR="\033[0m"

function ech {
  echo -e -n $GRAY`date -Iseconds` $NO_COLOR
  echo -e "$@"
}

function execute {
  echo -e "  Executing $GREEN$@$NO_COLOR"
  echo -e -n $CYAN
  "$@" | sed 's/^/    /'
  echo -e -n $NO_COLOR
}

function getpid {
  local name="$@"
  local pid=`ps -ef | grep -- "$name" | grep -v grep | head -n 1 | awk '{print $2}'`
  if [ "x" != "x$pid" ] ; then
    echo $pid
  fi 
}

function lower {
  local name="$@"
  local pid=`getpid $name`
  if [ "x" != "x$pid" ] ; then
    local prio=`ps -p $pid --format ni -h`
    if [ ! -z "$prio" ] ; then
      if [ "$prio" -ne 19 ] ; then
        ech "Lowering priority of $CYAN$name$NO_COLOR"
        execute renice -n 19 -p $pid
        echo
      fi
    fi
  fi
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

function cleanup {
  if [ "xDONE" == "x$CLEANUP" ] ; then
    exit 0
  fi
  CLEANUP=DONE

  set +e

  ech "Cleaning up"
  mousecolor "#000000"

  tweak_key_repeat

  killproc "Battle.net.exe"
  killproc "Battle.net Help"
  killproc "Agent.exe"
  killproc "SC2.*.exe"
  killproc "wineserver"
  killproc "C:\\\\windows\\\\system32"

  ech "Done"
  exit 0
}

trap "cleanup" SIGINT SIGTERM EXIT

function mousecolor {
  ech Setting mouse color to "$1"
  for i in {1..5}; do rivalcfg -c "$1"; done
}

function tweak_key_repeat {
  # This works on X but not on wayland
  local focused=$(xdotool getwindowfocus getwindowpid 2>/dev/null)

  # Workaround for wayland - enable if process is running
  #local focused=$1
  if [ "x$focused" == "x$pid" ] ; then
    if [ "$fast_repeat" != "enabled" ] ; then
      fast_repeat="enabled"

      # Speed up key repeat for faster warpins
      execute xset r rate 150 200

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

  mousecolor "$color"

  echo -e "Waiting for $CYAN$game$NO_COLOR ($LIGHT_CYAN$pid$NO_COLOR) to exit..."
  while ps --pid $pid > /dev/null; do
    lower_all
    tweak_key_repeat $pid
    sleep 5
  done
  echo

  ech "$CYAN$game$NO_COLOR has exited"

  mousecolor "#000000"

  echo
}

function main {
  ech "Launching Battle.net"
  WINEDEBUG=-all wine ~/.wine/drive_c/Program\ Files/Blizzard\ App/Battle.net.exe &>/dev/null &

  local fast_repeat=""
 
  while true; do
    ech "Waiting for SC2 to start..."
    while true; do
      lower_all

      local pid=`getpid SC2.exe`
      if [ "x" != "x$pid" ] ; then
        echo
        optimize $pid 2,3 "Starcraft 2" "#ff2200"
        break
      fi

      tweak_key_repeat _disable_
      sleep 5
    done
  done
}

ech "Disable mouse acceleration"
execute xset m 0 0

regex='[^A-Za-z0-9]+[:space:]*(.*)[:space:]*id=([0-9]+)'
regex2="libinput[:space:]*([^:space:].*)[:space:]*\\(([0-9]+)\\).*:.*([0-9]+)"
xinput list|grep -Eo "↳.*id=[0-9]+" | while read line ; do
  if [[ $line =~ $regex ]] ; then
    device="${BASH_REMATCH[1]}"
    device=$(echo -n "$device" | sed 's/[[:blank:]]*$//')
    id="${BASH_REMATCH[2]}"

    xinput list-props $id | grep Emulation | while read line2 ; do
      if [[ $line2 =~ $regex2 ]] ; then
        text="${BASH_REMATCH[1]}"
        text=$(echo -n "$text" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
        prop="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"
        if [ $value != "0" ] ; then
          ech "Setting $text = 0 for $device"
          execute xinput set-int-prop $id $prop 8 0
        fi
      fi
    done
  fi
done

main

