#!/bin/sh

# MIT License
#
# (C) Copyright [2021] Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

set -e

function help() {
  echo ""
  echo "An internal Cray tool for operations around Helm charts"
  echo ""
  echo "Usage:"
  echo "  chartsutil [command]"
  echo ""
  echo "Available commands:"
  echo "  test          test a chart or charts that are in the current local directory of your machine"
  echo "  render        render a chart or charts that are in the current local directory of your machine,"
  echo "                for manually verifying rendering"
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

function get_repo_url() {
  local repo_name="$1"
  printf "%s" $(helm repo list | grep '^'$repo_name'\s' | awk -F ' ' '{print $2}')
}

function get_chart_value() {
  local chart_path="$1"
  local chart_key="$2"
  chart_value=$(helm inspect chart $chart_path | grep ^$chart_key: | head -1 | awk -F ':' '{print $2}')
  chart_value=$(echo $chart_value | sed 's|\s+||g')
  chart_value=$(echo $chart_value | sed 's|"||g')
  printf "%s" $chart_value
}

if [[ -f /mounted/Chart.yaml ]]; then
  chart_name=$(get_chart_value /mounted "name")
  if [ -s /charts/$chart_name ]; then
    rm /charts/$chart_name
  fi
  ln -s /mounted /charts/$chart_name
else
  mounted_charts=$(ls /mounted/)
  for chart in $mounted_charts; do
    if [[ -d /mounted/$chart ]] && [[ -f /mounted/$chart/Chart.yaml ]]; then
      if [ -s /charts/$chart ]; then
        rm /charts/$chart
      fi
      ln -s /mounted/$chart /charts/$chart
    fi
  done
fi

available_charts=$(ls /charts/)
if [[ "$command" == "test" ]]; then
  for chart in $available_charts; do
    if [[ -d /charts/$chart ]] && [[ -f /charts/$chart/Chart.yaml ]]; then
      echo "Testing Helm chart at /charts/$chart..."
      if [ -f /charts/$chart/requirements.yaml ]; then
        extra_dep_up_args=""
        if [[ "$SKIP_HELM_DEP_UP_REFRESH" == true ]]; then
          extra_dep_up_args=" --skip-refresh"
        fi
        helm dep up${extra_dep_up_args} "/charts/$chart"
        export SKIP_HELM_DEP_UP_REFRESH=true
      fi
      helm lint "/charts/$chart"
      helm unittest --helm3 --with-subchart=0 "/charts/$chart"
      version=$(helm inspect chart "/charts/$chart" | grep ^version: | awk '{print $2}')
      chart-version-validate $version
    fi
  done
elif [[ "$command" == "render" ]]; then
  for chart in $available_charts; do
    if [[ -d /charts/$chart ]] && [[ -f /charts/$chart/Chart.yaml ]]; then
      echo "Rendering Helm chart at /charts/$chart..."
      if [ -f /charts/$chart/requirements.yaml ]; then
        extra_dep_up_args=""
        if [[ "$SKIP_HELM_DEP_UP_REFRESH" == true ]]; then
          extra_dep_up_args=" --skip-refresh"
        fi
        helm dep up${extra_dep_up_args} "/charts/$chart"
        export SKIP_HELM_DEP_UP_REFRESH=true
      fi
      helm template "/charts/$chart"
    fi
  done
# publish undocumented, should only be used in automated pipelines, never by the end user
elif [[ "$command" == "publish" ]]; then
  to_publish_path="$(cd /charts/$1 && pwd -P)"
  to_publish=$(ls $to_publish_path)
  for chart in $to_publish; do
    if echo $chart | grep '\.tgz$' &> /dev/null; then
      echo "Publishing Helm chart at $to_publish_path/$chart..."
      chart_name=$(get_chart_value $to_publish_path/$chart "name")
      chart_version=$(get_chart_value $to_publish_path/$chart "version")
      cray_internal_repo_url=$(get_repo_url "cray-internal")
      existing_chart_data_url="$cray_internal_repo_url/api/charts/$chart_name/$chart_version"
      echo "Checking for existing chart data at $existing_chart_data_url"
      existing_chart_data=$(curl -s -L -X GET $existing_chart_data_url)
      existing_chart_get_error=$(echo $existing_chart_data | jq -r '.error')
      if echo $existing_chart_get_error | grep '^[Nn]o chart' &> /dev/null; then
        echo "Publishing new Helm chart version $chart_name:$chart_version"
        curl -s -L --data-binary "@$to_publish_path/$chart" "$cray_internal_repo_url/api/charts"
        echo ""
      elif [[ "$existing_chart_get_error" == "null" ]] || [[ -z "$existing_chart_get_error" ]]; then
        existing_chart_url="$cray_internal_repo_url/$(echo $existing_chart_data | jq -r '.urls[0]')"
        mkdir -p /tmp/existing/$chart_name
        mkdir -p /tmp/new
        echo "Downloading existing Helm chart from $existing_chart_url"
        curl -s -L "$existing_chart_url" | tar -xzf - -C /tmp/existing
        tar -xzf $to_publish_path/$chart -C /tmp/new
        echo "Comparing existing Helm chart content to the newly packaged one"
        if ! diff -r /tmp/existing/$chart_name /tmp/new/$chart_name -x '*.lock' -x 'charts'; then
          echo "Error: Helm chart $chart_name:$chart_version has been modified, but the version number has not been incremented"
          exit 1
        fi
        echo "Your Helm chart $chart_name:$chart_version is identical to the one published, moving on"
      else
        echo "Error: trying to check for existing chart $chart_name:$chart_version, published chart: $existing_chart_get_error"
        exit 1
      fi
    fi
  done
# unpublish undocumented, should only be used in automated pipeline testing, never by the end user
elif [[ "$command" == "unpublish" ]]; then
  chart_name="$1"
  chart_version="$2"
  cray_internal_repo_url=$(get_repo_url "cray-internal")
  curl -X DELETE $cray_internal_repo_url/api/charts/${chart_name}/${chart_version}
else
  echo "Command $command is invalid"
  help
  exit 1
fi
