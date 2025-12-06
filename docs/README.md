# GitOps CI/CD in Kubernetes

## A Hands-on Practical Guide to Building a Fully Automated CI/CD Pipeline Using GitLab CI and GitOps Argo CD on Kubernetes

![gitops-featured-image](./images/img_k8s_gitops_cicd_drawio.png)

## Introduction

This hands-on practical guide is to demonstrate GitOps CI/CD automation in Kubernetes with GitLab CI and Argo CD using the [podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample) Python application. It mainly focuses on how to containerize an application, configure Continuous Integration (CI), Continuous Deployment (CD) and fully automated application deployment on Kubernetes.

## Summary: Objectives

What you'll learn in this hands-on practical guide:

- Write a [Dockerfile](https://docs.docker.com/reference/dockerfile/) to containerize a sample Python application.
- Configure the [GitLab CI](https://docs.gitlab.com/ci/) pipeline to build and push Docker container images using Buildah.
- Setup a Kubernetes Cluster with [K3s, Lightweight Kubernetes](https://k3s.io/).
- Write a [Helm Chart](https://helm.sh/) to deploy the podinfo-sample Python application on Kubernetes.
- Configure [Argo CD](https://argo-cd.readthedocs.io/en/stable/) as GitOps CD to deploy applications automatically on Kubernetes.
- Configure [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/en/stable/) to automate updating and pulling the Docker container images automatically.

This GitOps hands-on practical guide is based on the [GitOps in Kubernetes with GitLab CI and ArgoCD](https://levelup.gitconnected.com/gitops-in-kubernetes-with-gitlab-ci-and-argocd-9e20b5d3b55b) article by Poom Wettayakorn. But, I will share more details and focus on a beginner-friently guide.

## Prerequisites

Make sure you have installed the following:

- Familiar with basic Linux commands
- Docker Engine
- Linux installed VM or server or local machine (Ubuntu, Fedora, RHEL, etc.)

## [1] Containerizing an application

> [!NOTE]
> 
> **Before You Begin**
>
> Make sure you are familiar with Docker before you begin.
>
> - Install Docker: https://www.docker.com/get-started
> - Dockerfile Reference: https://docs.docker.com/reference/dockerfile
>
> If you are not familiar with Docker, please learn it first with the following _Docker for Beginners_ tutorial.
>
> Docker for Beginners: https://docker-curriculum.com/

In this guide, I will use the [podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample) Python application to demonstrate GitOps in Kubernetes. Firstly, you will need to write Dockerfile to containerize this Python application.

Git Repository: [https://gitlab.com/thezawzaw/podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample)

Fork this Git repository under your namespace and clone with the Git command-line tool.

```sh
$ git clone git@gitlab.com:<your-username>/podinfo-sample.git
```

For example, replace `gitops-example` with your username.

```sh
$ git clone git@gitlab.com:gitops-example/podinfo-sample.git
```

### Writing a Dockerfile

In the [podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample) Git repository, I've already written a Dockerfile to containerize the app.

```Dockerfile
#
# Stage (1): Builder Stage
#
# Install the app source code and required Python packages.
#
FROM python:3.12-alpine AS builder

ENV APP_WORKDIR=/app
ENV PATH="${APP_WORKDIR}/venv/bin:$PATH"

WORKDIR ${APP_WORKDIR}

COPY . .

RUN apk add --no-cache \
    gcc musl-dev && \
    python -m venv venv && \
    pip install --upgrade pip && \
    pip install -r requirements.txt

#
# Stage (2): Runtime Stage
#
# The final runtime environment for serving the Podinfo sample application.
#
FROM python:3.12-alpine AS runtime

ENV FLASK_APP=run.py
ENV APP_WORKDIR=/app
ENV APP_USER=zawzaw
ENV APP_GROUP=zawzaw
ENV APP_PORT=5005
ENV PATH="${APP_WORKDIR}/venv/bin:$PATH"

RUN adduser -D ${APP_USER}

WORKDIR ${APP_WORKDIR}

RUN pip uninstall pip -y
COPY --from=builder --chown=${APP_USER}:${APP_GROUP} ${APP_WORKDIR} ${APP_WORKDIR}

USER ${APP_USER}

EXPOSE ${APP_PORT}

ENTRYPOINT ["gunicorn", "--config", "gunicorn-cfg.py", "run:app"]
```

**_Explanation:_**

In the Stage (1) — Builder Stage:

- Create an application workdir.
- Add the application source code, create the Python virtual environment (venv) and install required packages with pip.

In the Stage (2) — Runtime Stage:

- Copy the created Python venv from the builder stage.
- Then, create and switch to a normal user and serve the Podinfo Python application with the Gunicorn server.

### Building and Testing the Container Image Locally

To build the Docker image locally, run the following `docker build` command:

```
$ cd podinfo-sample
$ docker build -t podinfo-sample:local .
```

To run and test the Podinfo application locally with `docker run`:

```
$ docker run -p 5005:5005 -it --rm --name podinfo podinfo-sample:local
```

To test the Podinfo application locally, open the following localhost address in the web browser:

URL: [http://localhost:5005](http://localhost:5005)

![podinfo-sample-image](./images/imge_screenshot_podinfo.png)

---

## [2] Building GitLab CI Pipeline

> [!NOTE]
> 
> **Before You Begin**
> 
> Make sure you've learned the basics of GitLab CI and YAML syntax. Please, start with the following tutorials.
> 
>  - Get started with GitLab CI: https://docs.gitlab.com/ci/
>  - CI/CD YAML Syntax Reference: https://docs.gitlab.com/ci/yaml/

In this section, I will use Buildah to build and push Docker container images automatically to the Harbor Docker registry.

[Buildah](https://github.com/containers/buildah) is a tool that facilitates building [Open Container Initiative (OCI)](https://www.opencontainers.org/) Container images. Buildah is designed to run in **Userspace**, also known as **Rootless mode** and does not require a root-privileged daemon like traditional Docker daemon. This is one of its primary advantages, especially in secured and automated CI/CD environments. Please, see the following GitHub wiki page.

**Building Container Images with Buildah in GitLab CI:** https://github.com/thezawzaw/platform-wiki/wiki/Building-Container-Images-with-Buildah-in-GitLab-CI

### GitLab CI Configuration

Firsty, you need to fork the Podinfo sample application repository that I've mentioned previously. (If you are already forked, you don't need to fork again.)

Podinfo Sample Git Repository: https://gitlab.com/thezawzaw/podinfo-sample

Then, you need to add two GitLab CI variables `REGISTRY_HOST` `DOCKER_CFG` on the Podinfo repository:

Go to your Podinfo Git repository >> <kbd>Project Settings</kbd> >> <kbd>CI/CD</kbd> >> <kbd>Variables</kbd>, and add the following key/value GitLab CI variables.

> [!NOTE]
> Replace with your container registry credentials.
>
> - Key: `REGISTRY_HOST`, Value: `<your-registry-host>`
> - Key: `DOCKER_CFG`, Value: `<your-registry-auth-creds>`

For example,
- REGISTRY_HOST: `harbor-dev-repo.ops.io`
- DOCKER_CFG: `{"auths": {"harbor-dev-repo.ops.io": {"auth": "YWRtaW46SGFyYm9yMTIzNDU="}}}`

I've already created `.gitlab-ci.yml` GitLab CI configuration on the Podinfo Git repository. But, you can write your own `.gitlab-ci.yml` configuration under your Podinfo sample project's root directory.

GitLab CI Configuration [https://gitlab.com/thezawzaw/podinfo-sample/-/blob/main/.gitlab-ci.yml](https://gitlab.com/thezawzaw/podinfo-sample/-/blob/main/.gitlab-ci.yml)

```yaml
#
# GitLab CI Configuration
#

#
# Define the CI stages here.
#
stages:
  - build
  - scan

# Define global variables here.
variables:
  IMAGE_REPO: "${REGISTRY_HOST}/library/${CI_PROJECT_NAME}"

###################################################################################
#                                                                                 #
# GitLab CI Templates                                                             #
#                                                                                 #
###################################################################################

# Template ---> template_build
# to build and push the Docker container images to the Container Registry server.
.template_build: &template_build
  stage: build
  image: quay.io/buildah/stable
  variables:
    BUILDAH_FORMAT: docker
    TARGET_IMAGE_TAG: ""
  script:
    - echo ${DOCKER_CFG} > /home/build/config.json
    - export REGISTRY_AUTH_FILE=/home/build/config.json
    - echo "Building Docker container image [ $IMAGE_REPO:$TARGET_IMAGE_TAG ]..."
    - >-
      buildah build
      --file ${CI_PROJECT_DIR}/Dockerfile
      --layers
      --cache-to ${IMAGE_REPO}/cache
      --cache-from ${IMAGE_REPO}/cache
      --tls-verify=false
      --tag ${IMAGE_REPO}:${TARGET_IMAGE_TAG} .
    - buildah push --tls-verify=false ${IMAGE_REPO}:${TARGET_IMAGE_TAG}
    - buildah rmi -f ${IMAGE_REPO}:${TARGET_IMAGE_TAG}

# Template ---> template_trivy_scan
# to scan and find vulnerabilities of the Docker container images.
.template_trivy_scan: &template_trivy_scan
  stage: scan
  image:
    name: docker.io/aquasec/trivy:0.67.2
    entrypoint: [""]
  variables:
    TRIVY_SEVERITY: "HIGH,CRITICAL"
    TRIVY_EXIT_CODE: "1"
    TARGET_IMAGE_TAG: ""
  script:
    - echo "Scanning Docker container image [ $IMAGE_REPO:$TARGET_IMAGE_TAG ]..."
    - >-
      trivy --cache-dir "${CI_PROJECT_DIR}/trivy/"
      image
      --image-src remote
      --insecure ${IMAGE_REPO}:${TARGET_IMAGE_TAG}
  cache:
    key: trivy-cache
    paths:
      - "${CI_PROJECT_DIR}/trivy/"
  when: manual


##########################################################################################
#                                                                                        #
# GitLab CI Jobs                                                                         #
#                                                                                        #
##########################################################################################

#
# Build CI Job ---> build-image-dev
# to build the Docker container image with the Git branch name as image tag name when you push changes into the 'develop' branch.
#
build-image-dev:
  <<: *template_build
  variables:
    TARGET_IMAGE_TAG: "${CI_COMMIT_REF_SLUG}"
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'

#
# Build CI Job ---> build-image-main
# to build the Docker container image with latest image tag name when you push changes into the 'main' branch.
#
build-image-main:
  <<: *template_build
  variables:
    TARGET_IMAGE_TAG: "latest"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

#
# Build CI Job ---> build-image-tag
# to build the Docker container image with the Git tag name as image tag when you create a Git tag.
#
build-image-tag:
  <<: *template_build
  variables:
    TARGET_IMAGE_TAG: "${CI_COMMIT_TAG}"
  rules:
    - if: "$CI_COMMIT_TAG"

#
# Scan CI Job ---> trivy-scan-dev
# to scan and find vulnerabilities of the Docker container image when you push changes into the 'develop' branch.
#
trivy-scan-dev:
  <<: *template_trivy_scan
  variables:
    TARGET_IMAGE_TAG: "${CI_COMMIT_REF_SLUG}"
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'

#
# Scan CI Job ---> trivy-scan-main
# to scan and find vulnerabilities of the Docker container image when push changes into the 'main' branch.
#
trivy-scan-main:
  <<: *template_trivy_scan
  variables:
    TARGET_IMAGE_TAG: "latest"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

#
# Scan CI Job ---> trivy-scan-tag
# to scan and find vulnerabilities of the Docker container image when you create a Git tag.
#
trivy-scan-tag:
  <<: *template_trivy_scan
  variables:
    TARGET_IMAGE_TAG: "${CI_COMMIT_TAG}"
  rules:
    - if: "$CI_COMMIT_TAG"
```

**_Explanation:_**

[Buildah](https://github.com/containers/buildah) builds the Docker container image of the Podinfo application with Dockerfile and pushes the target container image to internal Harbor container registry server when you push changes into the podinfo-sample Git repository.

---

## [3] Creating a Kubernetes Cluster with K3s

> [!NOTE]
> If you already have a Kubernetes cluster on your local machine or server, you can skip this step.

In this section, you will learn how to set up a Kubernetes cluster with K3s. I will use K3s in this guide, but you can also use any other Kubernetes distribution.

[K3s](https://k3s.io/) is a small, minimal, and lightweight Kubernetes distribution, developed and maintained by Rancher. K3s is easy to install, half the memory, all in a single binary of less than 100MB that reduces the dependencies and steps needed to install, run and auto-update a production Kubernetes cluster.

The K3s Official Documentation: [https://docs.k3s.io/](https://docs.k3s.io/)

### Set up a K3s Kubernetes Cluster

To set up a K3s Kubernetes cluster, run the following script:

```sh
#!/usr/bin/env bash

#
# A Shell Script
# to setup and bootstrap the K3s server, also known as Kubernetes control-plane/master node
#
# This script is for setup the single-node K3s Kubernetes cluster.
#

curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644
```

This installation script is for bootstrapping and creating the single-node K3s Kubernetes cluster with proper permissions to the default kubeconfig file.

You can also learn how to install on the K8s quickstart guide: [https://docs.k3s.io/quick-start](https://docs.k3s.io/quick-start)

### Install Freelens Kubernetes IDE

In this guide, I will use Freelens, a Kubernetes IDE, to manage the K3s Kubernetes cluster.

Freelens is a free and open-source Kubernetes IDE that provides a graphical user interface (UI) for managing and monitoring Kubernetes clusters. Freelens is currently maintained by the community.

The Official Website: [https://freelensapp.github.io/](https://freelensapp.github.io/)

Download the Freelens package with curl, for example, RPM-based Linux systems,

```sh
curl -LO https://github.com/freelensapp/freelens/releases/download/v1.7.0/Freelens-1.7.0-linux-amd64.rpm
```

Install the Freelens, for example, RPM-based Linux systems,

```sh
sudo dnf install ./Freelens-1.7.0-linux-amd64.rpm
```

For more option on installing the Freelens package, please see on GitHub: [https://github.com/freelensapp/freelens/blob/main/README.md#downloads](https://github.com/freelensapp/freelens/blob/main/README.md#downloads)

---

## [4] Building a Kubernetes Helm Chart

Before you write a Kubernetes Helm chart for the Podinfo sample application, make sure you understand Kubernetes core components and resource types. For example, Kubernetes cluster architecture, nodes, services, pods, deployments, ingress, and so on.

Firstly, you must learn to understand Kubernetes basics. If you are a beginner, I would like to recommend the following useful links to learn Kubernetes:

- Learn Kubernetes Basics: [https://kubernetes.io/docs/tutorials/kubernetes-basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- Kubernetes Core Concepts and Components: [https://kubernetes.io/docs/concepts/](https://kubernetes.io/docs/concepts/)

### Introduction to Helm

**Helm** is a Kubernetes package manager CLI tool that manages and deploys Helm charts.

**Helm Charts** are collection and packages of pre-configured application ressources which can be deployed as one unit. Helm charts help you define, install, upgrade and deploy applications easily on Kubernetes cluster.

 - The Offical Website: [https://helm.sh/](https://helm.sh/)
 - Helm Charts: [https://artifacthub.io/](https://artifacthub.io/)

### Installation and Setup

To install the Helm command-line tool with script, run the following command:

```sh
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
```

```sh
$ chmod 700 get_helm.sh && ./get_helm.sh
```

(OR)

You can install the Helm command-line tool with any other package managers. Please, see on the Helm documentation: [https://helm.sh/docs/intro/install#through-package-managers](https://helm.sh/docs/intro/install#through-package-managers).

