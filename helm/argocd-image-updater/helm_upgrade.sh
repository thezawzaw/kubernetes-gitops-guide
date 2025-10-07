#!/usr/bin/env bash
#
# A Shell Script
# to install and upgrade ArgoCD Image Updater Helm chart on the Kubernetes cluster.
#

helm repo add argo https://argoproj.github.io/argo-helm && \
helm upgrade --install \
  argocd-image-updater argo/argocd-image-updater \
  --namespace argocd \
  --create-namespace \
  --values values.yaml

