# Ingress NGINX Helm Chart

## Chart Information

 - **Helm Repository**: [https://kubernetes.github.io/ingress-nginx](https://kubernetes.github.io/ingress-nginx)
 - **ArtifactHub**: [https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx)
 - **Current Deployed App Version**: `1.13.2`
 - **Current Deployed Chart Version**: `ingress-nginx-4.13.2`

## Install and Upgrade

Add the Ingress NGINX Helm repository:

```sh
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

Install and upgrade the Ingress NGINX Helm chart by running the script:

```sh
$ cd helm/ingress-nginx
$ ./helm_upgrade.sh
```


## Latest Helm Upgrade Status

```sh
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
ingress-nginx   ingress-nginx   3               2025-09-22 08:31:02.481293727 +0800 PST deployed        ingress-nginx-4.13.2    1.13.2
```

