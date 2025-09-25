#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade Ingress NGINX Helm chart on the Kubernetes cluster.
#

helm upgrade --install \
  ingress-nginx ingress-nginx/ingress-nginx \
  --values values.yaml --namespace ingress-nginx --create-namespace

