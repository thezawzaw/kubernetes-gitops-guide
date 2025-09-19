# Cert-Manager Helm Chart

## Chart Information

 - **Helm Repository**: [https://charts.jetstack.io](https://charts.jetstack.io)
 - **ArtifactHub**: [https://artifacthub.io/packages/helm/cert-manager/cert-manager](https://artifacthub.io/packages/helm/cert-manager/cert-manager)
 - **Current Deployed App Version**: `v1.18.2`
 - **Current Deployed Chart Version**: `v1.18.2`

## Install and Upgrade

Add the Cert-Manager Helm repository:

```sh
$ helm repo add cert-manager https://charts.jetstack.io
```

Install and upgrade the Cert-Manager Helm chart by running the script:

```sh
$ cd helm/cert-manager
$ ./helm_upgrade.sh
```


## Latest Helm Upgrade Status

```sh
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
cert-manager    cert-manager    2               2025-09-19 16:19:21.586692383 +0800 PST deployed        cert-manager-v1.18.2    v1.18.2
```

