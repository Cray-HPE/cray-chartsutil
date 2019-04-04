# Cray Helm Charts Utility

1. Unit test helm charts with https://github.com/lrills/helm-unittest
2. Run other helm tasks in the container, like templating

## Using this Utility

[Install `craypc` and it's requirements](https://stash.us.cray.com/projects/CLOUD/repos/craypc/browse/README.md)

Then, for more info on running the utility:
```
craypc chartsutil --help
```

## Developing

### Releasing for `craypc`

Make necessary changes, increment version in:

1. `.craypc/config.yaml`

```
# this method will go away when we roll things into the DST pipeline appropriately
craypc local publish
```

