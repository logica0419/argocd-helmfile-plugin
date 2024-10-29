#!/bin/bash

# To enable the "lookup" function in the Helm template generation, we need to
# set the "--dry-run" option to "server".
# ref: https://github.com/argoproj/argo-cd/issues/5202#issuecomment-2040122017

if
  [[ ("$ENABLE_LOOKUP" != "" || "$ARGOCD_ENV_ENABLE_LOOKUP" != "") &&
    "$1" == "template" ]]
then
  /usr/local/bin/helm "$@" --dry-run=server
else
  /usr/local/bin/helm "$@"
fi
