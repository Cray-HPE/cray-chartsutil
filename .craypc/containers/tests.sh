#!/bin/sh

set -e

echo "===> Running chartsutil tests..."

echo "===> Starting local chartmuseum for tests"
mkdir -p /var/chartstorage
chartmuseum --port=8080 \
  --storage="local" \
  --storage-local-rootdir="/var/chartstorage" &
helm repo rm cray-internal
helm repo add cray-internal http://localhost:8080
helm repo up

mkdir -p /charts
echo "===> Testing helm by creating a single chart to be used in tests"
helm create /mounted/test-chart-01

echo "===> Testing /entrypoint.sh test on /mounted/test-chart-01"
/entrypoint.sh test

echo "===> Testing /entrypoint.sh test on /mounted/test-chart-01 with invalid version"
sed -i.bak 's/^version:.*$/version: 0.1-invalid/g' /mounted/test-chart-01/Chart.yaml
set +e
if /entrypoint.sh test; then
  echo "Didn't get expected error from /entrypoint.sh test for /mounted/test-chart-01 with invalid version"
  echo "content of Chart.yaml:"
  echo ""
  cat /mounted/test-chart-01/Chart.yaml
  echo ""
  exit 1
fi
mv /mounted/test-chart-01/Chart.yaml.bak /mounted/test-chart-01/Chart.yaml
set -e

echo "===> Testing /entrypoint.sh render on /mounted/test-chart-01"
/entrypoint.sh render

echo "===> Create another chart in /mounted/ so we can test multiple chart tests/renders"
helm create /mounted/test-chart-02
/entrypoint.sh test
/entrypoint.sh render

echo "===> Testing packaging of /mounted/test-chart-01 to /charts/.packaged/"
mkdir -p /charts/.packaged
helm package /mounted/test-chart-01 -d /charts/.packaged/

echo "===> Test publishing /mounted/test-chart-01 to ensure initial publish works as expected"
/entrypoint.sh publish ./.packaged

echo "===> Test publishing /mounted/test-chart-01 again, make sure the diff works as expected"
if ! /entrypoint.sh publish ./.packaged | grep 'identical to the one published'; then
  echo "Didn't find expected output for diff on unchanged chart"
  exit 1
fi

echo "===> Test publishing /mounted/test-chart-01 with changes to make sure it fails without incrementing the version"
sed -i 's/IfNotPresent/Always/g' /mounted/test-chart-01/values.yaml
helm package /mounted/test-chart-01 -d /charts/.packaged/
set +e
if ! /entrypoint.sh publish ./.packaged | grep 'has been modified'; then
  echo "Didn't find expected output for diff on changed chart"
  exit 1
fi
set -e

echo "===> Test publishing /mounted/test-chart-01 with changes and updated version"
rm /charts/.packaged/*
sed -i 's/^version:.*$/version: 1.1.1/g' /mounted/test-chart-01/Chart.yaml
cat /mounted/test-chart-01/Chart.yaml
helm package /mounted/test-chart-01 -d /charts/.packaged/
/entrypoint.sh publish ./.packaged
