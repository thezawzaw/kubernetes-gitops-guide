# Podinfo Helm Chart

A Kubernetes Helm Chart of the Podinfo Python sample application to deploy on the Kubernetes cluster.

---

## Installation

You can install the Podinfo Python sample application on a local Kubernetes cluster.

> This is only for testing on your local Kubernetes cluster.
> For testing purposes only, you don't need to use or install any GitOps CD tool. You just need to use the Helm command-line tool.

Download this GitOps repository:

```sh
git clone git@gitlab.com:thezawzaw/k8s-gitops-airnav-sample.git
```

Then, install the Podinfo Helm Chart with the Helm command-line tool:

```sh
cd helm/podinfo-app
helm install podinfo-app-sandbox ./ --values values.yaml --create-namespace --namespace sandbox
```

---

## Debugging the Helm Templates

You can also debug the Helm templates of the Podinfo application locally using the `helm template` command before you install it with Helm (or) any GitOps CD tool.

This command renders the Helm templates locally, and then you check for Helm syntax errors and whether your configuration is correct or not.

```sh
cd helm/podinfo-app
helm template podinfo-app-sandbox ./ --values values.yaml --namespace sandbox
```

