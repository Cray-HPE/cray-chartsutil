#!/bin/sh

set -e

function help() {
  echo "Usage:"
  echo "  chartsutil [command]"
  echo ""
  echo "Available commands:"
  echo "  test    test a chart or charts that are in the current local directory of your machine"
  echo "  render  render a chart or charts that are in the current local directory of your machine, for manually verifying rendering"
  echo ""
  echo ""
}

command="$1"
shift

if [ -z "$command" ]; then
  echo "Missing command"
  echo ""
  help
  exit 1
fi
if [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]] || [[ "$command" == "help" ]]; then
  help
  exit 0
fi

if [ -f /mounted/Chart.yaml ]; then
  chart_name=$(cat /mounted/Chart.yaml | grep ^name: | awk -F ':' '{print $2}')
  chart_name=$(echo $chart_name | sed 's|\s+||g')
  chart_name=$(echo $chart_name | sed 's|"||g')
  ln -s /mounted /charts/$chart_name
else
  for chart in $(ls /mounted/); do
    if [[ -d /mounted/$chart ]] && [[ -f /mounted/$chart/Chart.yaml ]]; then
      ln -s /mounted/$chart /charts/$chart
    fi
  done
fi

if [[ "$command" == "test" ]]; then
  for chart in $(ls /charts/); do
    if [[ -d /charts/$chart ]] && [[ -f /charts/$chart/Chart.yaml ]]; then
      echo "Testing chart at /charts/$chart..."
      helm lint "/charts/$chart"
      helm unittest "/charts/$chart"
    fi
  done
elif [[ "$command" == "render" ]]; then
  for chart in $(ls /charts/); do
    if [[ -d /charts/$chart ]] && [[ -f /charts/$chart/Chart.yaml ]]; then
      echo "Rendering chart at /charts/$chart..."
      helm template "/charts/$chart"
    fi
  done
else
  echo "Running non-standard command in the container: $@"
  help
  eval "$@"
fi
