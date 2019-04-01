#!/bin/bash

return_dir=$(pwd)
this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

local_charts_path="$1"

cd $this_dir
chart_name=""
if [ -f $local_charts_path/Chart.yaml ]; then
  chart_name="$(basename $local_charts_path)"
fi
docker run -it --rm -v "$local_charts_path:/charts/$chart_name" cray/charts-utility test
cd $return_dir
