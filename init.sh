#!/bin/sh

if ! (type task >/dev/null 2>&1); then
  echo "Please re-execute init.sh after installing task"
  echo "https://taskfile.dev/installation/"
fi

task init
