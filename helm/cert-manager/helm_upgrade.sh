#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade Cert-Manager Helm chart on the Kubernetes cluster.
#

helm upgrade --install \
  cert-manager cert-manager/cert-manager \
  --values values.yaml --create-namespace --namespace cert-manager

