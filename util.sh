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

