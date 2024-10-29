#!/bin/sh

if ! (type task >/dev/null 2>&1); then
  echo "Please install \"task\" before running this script."
  echo "https://taskfile.dev/installation/"
fi

task init
