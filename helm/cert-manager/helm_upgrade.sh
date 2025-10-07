#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade Cert-Manager Helm chart on the Kubernetes cluster.
#
helm repo add cert-manager https://charts.jetstack.io && \
helm upgrade --install \
  cert-manager cert-manager/cert-manager \
  --values values.yaml --create-namespace --namespace cert-manager

kubectl apply -f issuers/selfsigned-clusterissuer.yaml

