# k8s-gitops-airnav-dev

GitOps ArgoCD Configurations for the AirNav K8s Dev Cluster and Apps

## GitOps Repository Structure

  - `argocd/apps`: A composed app (App of Apps pattern) to deploy the multiple apps at once. *For example,* when you create an Argo CD app (root app) via the UI, Argo CD automatically creates the apps (child apps) at once under `argocd/apps/templates/` on the Git repository.
    
  - `helm`: Kubernetes Helm charts to deploy your web apps and tools. *For example,* the Podinfo Helm Chart.

  - `kustomize/namespace-resources`: Required Namespace resources. *For example,* Docker image pull secrets for various namespaces are used by Kubernetes Helm Charts to pull the container images from the private container registry. *(It's ONLY NEEDED when you use a private Container registry.)*

 - `bootstrap_k3s.sh`: A shell script to boostrap and set up K3s Kubernetes cluster.

## Documentation

For detailed documentation, read the hands-on practical guide on [GitOps in K8s with GitLab CI and Argo CD](./docs/README.md).

