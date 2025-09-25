#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade ArgoCD Helm chart on the Kubernetes cluster.
#

helm upgrade --install \
  argocd argo/argo-cd \
  --values values.yaml --namespace argocd --create-namespace

