#!/bin/sh

set -e

if [[ "$1" == "test" ]]; then
  for chart in $(ls /charts/); do
    if [[ -d /charts/$chart ]] && [[ -f /charts/$chart/Chart.yaml ]]; then
      echo "Testing chart at /charts/$chart..."
      helm lint "/charts/$chart"
      helm unittest "/charts/$chart"
    fi
  done
else
  eval "$@"
fi
