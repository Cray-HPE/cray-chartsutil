#!/usr/bin/python

import sys
import semver

version = '{}'.format(sys.argv[1])
try:
    semver.parse(version)
except Exception:
    print 'ERROR: invalid semantic version for chart: {}'.format(version)
    sys.exit(1)
print 'chart version {} is valid semver'.format(version)
sys.exit()
