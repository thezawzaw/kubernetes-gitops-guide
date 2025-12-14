# GitOps in Kubernetes Guide

A Hands-on Practical Guide to Building a Fully Automated CI/CD Pipeline Using GitLab CI, GitOps Argo CD, and Argo CD Image Updater on Kubernetes.

## GitOps Repository Structure

  - `argocd/apps`: A composed app (App of Apps pattern) to deploy the multiple apps at once. *For example,* when you create an Argo CD app (root app) via the UI, Argo CD automatically creates the apps (child apps) at once under `argocd/apps/templates/` on the Git repository.
    
  - `helm`: Kubernetes Helm charts to deploy your web apps and tools. *For example,* the Podinfo Helm Chart.

  - `kustomize/namespace-resources`: Required Namespace resources. *For example,* Docker image pull secrets for various namespaces are used by Kubernetes Helm Charts to pull the container images from the private container registry. *(It's ONLY NEEDED when you use a private Container registry.)*

 - `bootstrap_k3s.sh`: A shell script to bootstrap and set up the K3s Kubernetes cluster.

## Hands-on Practical Guide

Read a comprehensive and hands-on practical guide on [GitOps in Kubernetes with GitLab CI + GitOps Argo CD + Argo CD Image Updater](./docs/README.md).

