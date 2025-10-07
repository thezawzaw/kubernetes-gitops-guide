#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade ArgoCD Helm chart on the Kubernetes cluster.
#

helm repo add argo https://argoproj.github.io/argo-helm && \
helm upgrade --install \
  argocd argo/argo-cd \
  --values values.yaml --namespace argocd --create-namespace

