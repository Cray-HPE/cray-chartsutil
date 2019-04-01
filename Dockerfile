##############################
# install
##############################
FROM alpine:latest as install

RUN apk add --no-cache git bash ca-certificates curl

ARG kubectl_version="v1.14.0"
ARG helm_version="v2.13.1"
RUN wget -q https://storage.googleapis.com/kubernetes-release/release/${kubectl_version}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl
RUN wget -q https://storage.googleapis.com/kubernetes-helm/helm-${helm_version}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

RUN helm init --client-only
RUN helm plugin install https://github.com/lrills/helm-unittest

##############################
# chart-utility
##############################
FROM alpine:latest as chart-utility

COPY --from=install /usr/local/bin/kubectl /usr/local/bin/
COPY --from=install /usr/local/bin/helm /usr/local/bin/
COPY --from=install /root/.helm /root/.helm

VOLUME [ "/charts" ]
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
