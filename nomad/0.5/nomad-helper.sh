#!/usr/bin/env bash

function check_exit {
  cmd_output=$($@)
  local status=$?
  echo "$cmd_output"
  if [ $status -eq 255 ]; then
    echo "$1 $2 exit status: $status, stopping..." >&2
    exit 255
  elif [ $status -ne 0 ]; then
    echo "$1 $2 exit status: $status, continuing..." >&2
  fi
  exit 0
}

function nomad_command {
  nomad $1 $2
}

case "$1" in
  plan)
    check_exit nomad_command $1 $2
    ;;

  run)
    check_exit nomad_command $1 $2
    ;;
  *)
    echo $"Usage: $0 {plan NOMAD_JOB_PATH|run NOMAD_JOB_PATH}"
    exit 1
esac
