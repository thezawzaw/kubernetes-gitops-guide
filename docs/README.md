# GitOps CI/CD in Kubernetes

## A Hands-on Practical Guide to Building a Fully Automated CI/CD Pipeline Using GitLab CI and GitOps Argo CD on Kubernetes

**PDF Format:** [The PDF version of the GitOps CI/CD in Kubernetes Guide is available here](./pdfs/k8s-gitops-cicd-guide.pdf).

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
- Linux installed VM or server or local machine (e.g., Ubuntu, Fedora, RHEL, etc.)

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

### Introduction to a sample Python application

In this guide, I will use the [podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample) Python application to demonstrate building a fully automated GitOps CI/CD pipeline in Kubernetes. 

Podinfo is an open-source and simple Python Flask application, originally developed by [Poom Wettayakorn](https://gitlab.com/gitops-argocd-demo/webapp) that shows the following information in UI:

 - **Namespace**
 - **Node Name**
 - **Pod Name**
 - **Pop IP Address**

![screenshot-podinfo-demo](./images/img_screenshot_podinfo_k8s_demo.jpeg)

I've forked Poom Wettayakorn's Podinfo application under my GitLab account and customized it. I will use the following customized version of the Podinfo sample app in this GitOps hands-on practical guide.

Git Repository: [https://gitlab.com/thezawzaw/podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample)

Fork this Git repository under your GitLab account and clone with the Git command-line tool.

```sh
$ git clone git@gitlab.com:<your-username>/podinfo-sample.git
```

For example, replace `gitops-example` with your username.

```sh
$ git clone git@gitlab.com:gitops-example/podinfo-sample.git
```

### Writing a Dockerfile

Firstly, you will need to write Dockerfile to containerize this Python web application. In the [podinfo-sample](https://gitlab.com/thezawzaw/podinfo-sample) Git repository, I've already written a Dockerfile to containerize the app.

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
C
To run and test the Podinfo application locally with `docker run`:

```
$ docker run -p 5005:5005 -it --rm --name podinfo podinfo-sample:local
```

To test the Podinfo application locally, open the following localhost address in the web browser:

URL: [http://localhost:5005](http://localhost:5005)

![screenshot-podinfo-docker](./images/img_screenshot_podinfo_docker.png)

---

## [2] Building GitLab CI Pipelines

### Introduction to GitLab CI

 - **GitLab CI** is a Continuous Integration (CI) that automates building and testing the code changes via a `.gitlab-ci.yml` file on your GitLab repository. *For Example,* in this GitOps CI/CD guide, I will use GitLab CI to build the container image of the Podinfo Python application automatically.

 - **GitLab Runner** is an application or server that runs GitLab CI jobs in a pipeline. GitLab CI jobs are defined and configured in the `.gitlab-ci.yml` file that automatically triggers when you push the code changes to GitLab. Then, GitLab Runner runs these CI jobs on the server or computing infrastructure. For more information about GitLab Runner, please see [https://docs.gitlab.com/runner/#what-gitlab-runner-does](https://docs.gitlab.com/runner/#what-gitlab-runner-does).

Before you begin, make sure you have learned the basics of GitLab CI and YAML syntax. Please, start with the following tutorials.

 - Get started with GitLab CI: https://docs.gitlab.com/ci/
 - CI/CD YAML Syntax Reference: https://docs.gitlab.com/ci/yaml/

### Installing and Registering a GitLab Runner

> [!NOTE]
>
> In this guide, I will use a self-managed GitLab Runner for running GitLab CI jobs for full control, but it's OPTIONAL.
>
> You can also use GitLab-hosted Runners. Please see [https://docs.gitlab.com/ci/runners/hosted_runners/linux/](https://docs.gitlab.com/ci/runners/hosted_runners/linux/). These Runners are managed and hosted by GitLab. You can use these GitLab Runners without installing and registering your own GitLab Runners.
>
> If you want to use GitLab-hosted Runners, you can skip this step.

GitLab provides the GitLab Runner packages for most Linux distributions. But, installation depends on your Linux distribution. In this guide, I will focus on RHEL-based Linux systems.

Add the following GitLab RPM repository (e.g., Fedora Linux):

```sh
$ curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
```

Install the GitLab Runner with `yum` or `dnf`:

```sh
$ sudo yum install gitlab-runner
```

(OR)

```sh
$ sudo dnf install gitlab-runner
```

For any other Linux distributions, please see [https://docs.gitlab.com/runner/install/linux-repository/](https://docs.gitlab.com/runner/install/linux-repository/).

After you install a GitLab Runner, you need to register this for your Podinfo Git repository. Firstly, you need to fork the Podinfo sample application repository that I've mentioned previously. *(If you have already forked, you don't need to fork again.)*

**Podinfo Sample Git Repository:** https://gitlab.com/thezawzaw/podinfo-sample

Go to your Podinfo Git repository >> <kbd>Settings</kbd> >> <kbd>CI/CD</kbd> >> <kbd>Runners</kbd> >> <kbd>Three dots menu</kbd> and then copy your <kbd>Registration token</kbd>. *(Note: Registration tokens are deprecated, but you can still use them.)*

And then, register with the GitLab URL and registration token. Replace with your actual registration token.

```sh
$ sudo gitlab-runner register --url https://gitlab.com/ --registration-token <example-token-here>
```

And then, you also need to set the `executor`, `docker-image`, and `description` in the *interactive* shell mode.

(OR)

Alternatively, you can register a GitLab Runner in the *non-interactive* shell mode.

```sh
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --token <your-registration-token> \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "GitLab Runner for the Podinfo application"
```

And then, you can check GitLab Runner `config.toml` configuration in the `/etc/gitlab-runner/config.toml` file.

```sh
$ cat /etc/gitlab-runner/config.toml
```

Output:

```toml
concurrent = 8
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "Podinfo GitLab Runner on Fedora Linux"
  url = "https://gitlab.com/"
  id = 50528940
  token = "<registration-token-example>" # Replace with your registration token.
  token_obtained_at = 2025-11-13T06:27:20Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    image = "alpine:latest"
    privileged = false
    tls_verify = false
    pull_policy = "if-not-present"
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    shm_size = 0
    network_mtu = 0
    volumes = ["/cache"]
```

### Configuring GitLab CI Pipeline to Build and Push Container Images

In this section, I will use Buildah to build and push Docker container images automatically to the Harbor Docker registry.

[Buildah](https://github.com/containers/buildah) is a tool that facilitates building [Open Container Initiative (OCI)](https://www.opencontainers.org/) Container images. Buildah is designed to run in **Userspace**, also known as **Rootless mode** and does not require a root-privileged daemon like traditional Docker daemon. This is one of its primary advantages, especially in secured and automated CI/CD environments. Please, see the following GitHub wiki page.

**Building Container Images with Buildah in GitLab CI:** https://github.com/thezawzaw/platform-wiki/wiki/Building-Container-Images-with-Buildah-in-GitLab-CI

Before you configure GitLab CI pipeline, make sure you add two GitLab CI variables `REGISTRY_HOST` `DOCKER_CFG` on the Podinfo repository:

Go to your Podinfo Git repository >> <kbd>Project Settings</kbd> >> <kbd>CI/CD</kbd> >> <kbd>Variables</kbd>, and add the following key/value GitLab CI variables.

> [!NOTE]
>
> Replace with your Container registry credentials.
>
> - Key: `REGISTRY_HOST`, Value: `<your-registry-host>`
> - Key: `DOCKER_CFG`, Value: `<your-registry-auth-creds>`

*For Example,*

| Key | Value |
| --- | --- |
| `REGISTRY_HOST` | `harbor-repo-example.io` |
| `DOCKER_CFG` | `{"auths": {"harbor-repo-example.io": {"auth": "emF3emF3OkhhcmJvckV4YW1wbGVQYXNzd29yZAo="}}}` |

 - `REGISTRY_HOST`: for your Container registry host.

 - `DOCKER_CFG`: for the credentials to access your Container registry server. You can find your Docker login credentials in the `~/.docker/config.json` file of the host machine.

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
```

**_Explanation:_**

When you push some changes into the Podinfo Git repository, GitLab CI builds the Docker container image of the Podinfo application using [Buildah](https://github.com/containers/buildah) and then, pushes the image to your Container registry server.

Container image name format ⟶  `<your-container-registry>/library/podinfo-sample:<image-tag-name>`

 - When you push changes into the `develop` branch, the `<image-tag-name>` will be `develop`.
 - When you push changes into the `master` branch, the `<image-tag-name>` will be `latest`.
 - When you create a Git tag on the Git repository, the `<image-tag-name>` will be the Git tag number you created.

*For Example,*

When I push some changes into the `master` branch, the container image name is `harbor-repo-example.io/library/podinfo-sample:latest`. You can also see the logs in the GitLab CI build job's logs. For reference, please see [https://gitlab.com/thezawzaw/podinfo-sample/-/jobs/12120436761](https://gitlab.com/thezawzaw/podinfo-sample/-/jobs/12120436761)

```
[2/2] COMMIT harbor-repo-example.io/library/podinfo-sample:latest
--> Pushing cache [harbor-repo-example.io/library/podinfo-sample/cache]:23c4fe872d978253fd66b2a50aa2d6e40da8a09c9f5fd79910fdf7855fc88d7a
--> 048e6533805b
Successfully tagged harbor-repo-example.io/library/podinfo-sample:latest
048e6533805b842328e03e7b1b9b2b5efdf2bce11d706283690a8dde4afc78d3
...
```

---

## [3] Creating a Kubernetes Cluster with K3s

> [!NOTE]
>
> If you already have a Kubernetes cluster on your local machine or server, you can skip this step.

In this section, you will learn how to set up a Kubernetes cluster with K3s. I will use K3s in this guide, but you can also use any other Kubernetes distribution.

[K3s](https://k3s.io/) is a small, minimal, and lightweight Kubernetes distribution, developed and maintained by Rancher. K3s is easy to install, half the memory, all in a single binary of less than 100MB that reduces the dependencies and steps needed to install, run and auto-update a production Kubernetes cluster.

The K3s Official Documentation: [https://docs.k3s.io/](https://docs.k3s.io/)

### Set up K3s Kubernetes Cluster

To bootstrap and set up a K3s Kubernetes cluster, run the following script:

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

This installation script is for bootstrapping and creating the single-node K3s Kubernetes cluster with proper permissions to the default kubeconfig file. You can also learn how to install on the K8s quickstart guide: [https://docs.k3s.io/quick-start](https://docs.k3s.io/quick-start)

Then, you can check your K3s Kubernetes cluster by running the `kubectl get node` command:

```sh
$ kubectl get node -o wide
```

Output:

```sh
AME                    STATUS   ROLES                  AGE   VERSION        INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                      KERNEL-VERSION                 CONTAINER-RUNTIME
airnav-dev-k3s-server   Ready    control-plane,master   22h   v1.33.4+k3s1   192.168.x.x   <none>        AlmaLinux 9.6 (Sage Margay)   5.14.0-570.41.1.el9_6.x86_64   containerd://2.0.5-k3s2
```

### Installing the Dashboard UI to manage Kubernetes Clusters

By default, K3s has built-in [kubectl](https://kubernetes.io/docs/reference/kubectl/), which is a client command-line tool mainly used to manage and communicate with the Kubernetes clusters. You can use both the *kubectl* command-line tool and the UI dashboard to manage your Kubernetes clusters.

For a UI dashboard to manage your Kubernetes clusters, I recommend you use Freelens Kubernetes IDE (or) the official Kubernetes Dashboard application.

#### Freelens Kubernetes IDE

![screenshot-freelens-ide](./images/img_screenshot_freelens_ide.png)

In this guide, I will use Freelens, a Kubernetes IDE, to manage the K3s Kubernetes cluster.

Freelens is a free and open-source Kubernetes IDE that provides a graphical user interface (UI) for managing and monitoring Kubernetes clusters. Freelens is currently maintained by the community.

 - GitHub Repository: [https://github.com/freelensapp/freelens](https://github.com/freelensapp/freelens)
 - The Official Website: [https://freelensapp.github.io/](https://freelensapp.github.io/)

Download the Freelens package with curl, for example, RPM-based Linux systems,

```sh
curl -LO https://github.com/freelensapp/freelens/releases/download/v1.7.0/Freelens-1.7.0-linux-amd64.rpm
```

Install the Freelens, for example, RPM-based Linux systems,

```sh
sudo dnf install ./Freelens-1.7.0-linux-amd64.rpm
```

For more option on installing the Freelens package, please see on GitHub: [https://github.com/freelensapp/freelens/blob/main/README.md#downloads](https://github.com/freelensapp/freelens/blob/main/README.md#downloads)

(OR)

#### Kubernetes Dashboard

![screenshot-k8s-dashboard](./images/img_screenshot_k8s_dashboard.png)

You can also use the official Kubernetes Dashboard. It is a general-purpose and web-based UI that allows users to manage the Kubernetes clusters and containerized applications running in the cluster and troubleshoot them.

 - GitHub Repository: [https://github.com/kubernetes/dashboard](https://github.com/kubernetes/dashboard)
 - Kubernetes Documentation: [https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

Please, see the detailed documentation on how to install Kubernetes Dashboard: [https://github.com/kubernetes/dashboard/blob/master/README.md#installation](https://github.com/kubernetes/dashboard/blob/master/README.md#installation)

---

## [4] Writing a Kubernetes Helm Chart from Scratch

> Before you write a Kubernetes Helm chart for the Podinfo sample application, make sure you understand **Kubernetes core components**, **Kubernete objects** and **workloads resources** first. If you are not familiar with Kubernetes, you can start with the [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics) tutorial.
> 
> Useful tutorials and guides to learn Kubernetes:
>
>  - Learn Kubernetes Basics: [https://kubernetes.io/docs/tutorials/kubernetes-basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
>  - Kubernetes Core Concepts and Components: [https://kubernetes.io/docs/concepts/](https://kubernetes.io/docs/concepts/)

In this section, I will write a Kubernetes Helm chart from scratch for the Podinfo Python application. I had published an article, and you can also learn about how to write a Kubernetes Helm chart from scratch with this article.

 - **Writing a Kubernetes Helm Chart from Scratch:** [https://www.zawzaw.blog/k8s-write-k8s-helm-chart/](https://www.zawzaw.blog/k8s-write-k8s-helm-chart/)

For reference, I've already written a Helm chart for the Podinfo Python application. Please, see the **Podinfo Helm Chart** on the following GitOps repository.

 - **Podinfo Helm Chart:** [https://gitlab.com/thezawzaw/k8s-gitops-airnav-sample/-/tree/main/helm/podinfo-app](https://gitlab.com/thezawzaw/k8s-gitops-airnav-sample/-/tree/main/helm/podinfo-app)

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

### Understanding application concepts

Before you write a Helm chart for your Podinfo application, make sure you understand the application's concept and how the application works.

In the Podinfo Python application, it will display the following information in the UI:

 - **Namespace**
 - **Node Name**
 - **Pod Name**
 - **Pop IP Address**

For example,

![screenshot-podinfo-details](./images/img_screenshot_cropped_podinfo.jpeg)

Basically, the Podinfo Python application retrieves the data or information dynamically via the Kubernetes environment variables. So, you need to expose the Pod and Node information to the container via the environment variables in Kubernetes. Then, the app uses these environment variables to retrieve information dynamically.

Reference: [Expose Pod Information to Containers Through Environment Variables](https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information)

For example, you can set these `ENV` variables with key/value form in your Kubernetes deployment like this:

```yaml
env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
- name: NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_IP
    valueFrom:
      fieldRef:
        fieldPath: status.podIP
```

It's key/value form like this:

 - `NODE_NAME`=`spec.nodeName`
 - `NAMESPCE`=`metadata.namespace`
 - `POD_NAME`=`metadata.name`
 - `POD_IP`=`status.podIP`

### Creating a Helm Chart with Helm CLI

Create a Helm chart with the Helm command-line tool:

```sh
$ cd ~/helm/
$ helm create podinfo-app
```

Then, Helm automatically generates and bootstraps the Helm templates and values like this:

```sh
[zawzaw@fedora-linux:~/helm/podinfo-app]$ tree
.
├── Chart.yaml
├── README.md
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── httproute.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml

3 directories, 12 files
```

### Customizing and Configuring Helm Chart

Basically, Helm Charts have main three categories:

 - `Chart.yaml`
   - Define Helm chart name, description, chart revision and so on.

 - `templates/`
   - Helm templates are general and dynamic configurations that locate Kubernetes resources
   written in YAML-based [Helm template language](https://helm.sh/docs/chart_template_guide).
   It means that we can pass variables from `values.yaml` file into templates files when we deploy Helm chart.
   So, values can be changed dynamically based on you configured Helm templates at deployment time.

 - `values.yaml`
   - Declare variables to be passed into Helm templates. So, when we run `helm install` to deploy Helm charts,
   Helm sets this variables into Helm templates files based on you configured templates and values.

In the other words, Helm charts are pre-configured configurations and packages as one unit to deploy applications esaily on Kubernetes cluster.

After initialize a new Helm chart, we need to customize Helm templates and values as you need. It depends on your web application.
For the Podinfo Helm Chart, we need to configure the following steps.

---

#### Set Docker container image

_**Values ▸ {HELM_CHART_ROOT}/values.yaml**_

In the `values.yaml` file, define variables for the Docker container image that we've built and pushed to your container registry.

```yaml
image:
  repository: harbor-repo-example.io/library/podinfo-sample:latest
  pullPolicy: IfNotPresent
  tag: "latest"
```

</br>

_**Deployment Template ▸ {HELM_CHART_ROOT}/templates/deployment.yaml**_

In the `templates/deployment.yaml` file, we can set variables from values.yaml with `.Values.image.repository`, `.Values.image.pullPolicay` and `.Values.image.tag`. It's YAML-based Helm template language syntax. You can learn on [The Chart Template Developer's Guide](https://helm.sh/docs/chart_template_guide).

  - Get Docker image repository: `.Values.image.repository`
  - Get Docker image pull policy: `.Values.image.pullPolicy`
  - Get Docker image tag: `.Values.image.tag`

So, when need to get variables form `values.yaml` file, we can use `.Values` in Helm templates like this:

```yaml
containers:
  - name: {{ .Chart.Name }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
```

---

#### Set Service Port and Target Port

_**Values ▸ {HELM_CHART_ROOT}/values.yaml**_

In the `values.yaml` file, define variables for sevice type, port and targetPort.

  ```yaml
  service:
    type: NodePort
    port: 80
    targetPort: http
  ```

</br>

_**Service Template ▸ {HELM_CHART_ROOT}/templates/service.yaml**_

In `templates/service.yaml` file, we can set service varibales from values.yaml file like this:
  
  - Get service type: `.Values.service.type`
  - Get service port: `.Values.service.port`
  - Get service target port: `.Values.service.targetPort`

```yaml
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
```

---

#### Set Target Docker Container Port

_**Values ▸ {HELM_CHART_ROOT}/values.yaml**_

In the `values.yaml` file, define a variable for the Container port number that the Podinfo app is serving and listening to.

```yaml
deployment:
  containerPort: 5005
```

</br>

_**Deployment Template ▸ {HELM_CHART_ROOT}/templates/deployment.yaml**_

In the `templates/deployment.yaml` file, set target Docker container port variable from values.yaml file:

Get target container port: `.Values.deployment.containerPort`

```yaml
containers:
 - name: {{ .Chart.Name }}
   ports:
    - name: http
      containerPort: {{ .Values.deployment.containerPort }}
      protocol: TCP
```

---

#### Set Environment Varibales

_**Values ▸ {HELM_CHART_ROOT}/values.yaml**_

In the `values.yaml` file, define environment variables that the Podinfo application retrieves the data in UI.

```yaml
deployment:
  env:
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
```

</br>

_**Deployment Template ▸ {HELM_CHART_ROOT}/templates/deployment.yaml**_

In `templates/deployment.yaml`, set environment variables dynamically from the values.yaml file. When you need to pass the array and whole config block into Helm templates, you can use `- with` and `- toYaml`.

```yaml
containers:
  - name: {{ .Chart.Name }}
    {{- with .Values.deployment.env }}
     env:
       {{- toYaml . | nindent 12 }}
    {{- end }}
```

---

### Debugging Helm Templates

After you build a Helm Chart for the Podinfo application, we can debug and test Helm templates locally with the `helm template` command.

The `helm template` command renders the Helm Chart templates and shows the output locally.

*Format:*

```sh
$ helm template <helm_release_name> <helm_chart_path> --values <values_file_path> --namespace <your_namespace>
```

*For Example:*

```sh
$ cd helm/podinfo-app
$ helm template podinfo-app-dev ./ --values values.yaml --namespace dev
```

If you have syntax errors, Helm shows error messages.

This is automatically generated and rendered by the Helm command-line tool based on your configured Helm templates and values.

```yaml
---
# Source: podinfo-app/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: podinfo-app-dev
  labels:
    helm.sh/chart: podinfo-app-0.1.0
    app.kubernetes.io/name: podinfo-app
    app.kubernetes.io/instance: podinfo-app-dev
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
automountServiceAccountToken: true
---
# Source: podinfo-app/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo-app-dev
  labels:
    helm.sh/chart: podinfo-app-0.1.0
    app.kubernetes.io/name: podinfo-app
    app.kubernetes.io/instance: podinfo-app-dev
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 5005
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: podinfo-app
    app.kubernetes.io/instance: podinfo-app-dev
---
# Source: podinfo-app/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo-app-dev
  labels:
    helm.sh/chart: podinfo-app-0.1.0
    app.kubernetes.io/name: podinfo-app
    app.kubernetes.io/instance: podinfo-app-dev
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: podinfo-app
      app.kubernetes.io/instance: podinfo-app-dev
  template:
    metadata:
      labels:
        helm.sh/chart: podinfo-app-0.1.0
        app.kubernetes.io/name: podinfo-app
        app.kubernetes.io/instance: podinfo-app-dev
        app.kubernetes.io/version: "1.16.0"
        app.kubernetes.io/managed-by: Helm
    spec:
      imagePullSecrets:
        - name: secret-registry-harbor
      serviceAccountName: podinfo-app-dev
      containers:
        - name: podinfo-app
          image: "harbor-repo-example.io/library/podinfo-sample:develop"
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 5005
              protocol: TCP
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
---
# Source: podinfo-app/templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "podinfo-app-dev-test-connection"
  labels:
    helm.sh/chart: podinfo-app-0.1.0
    app.kubernetes.io/name: podinfo-app
    app.kubernetes.io/instance: podinfo-app-dev
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['podinfo-app-dev:80']
  restartPolicy: Never
```

### Deploying the Podinfo Helm Chart Manually on Kubernetes Cluster

You can now deploy the Podinfo application with Helm Chart manually on your Kubernetes cluster.

Deploy the Podinfo application simply like this:

*Format:*

```sh
$ helm install <helm_release_name> <helm_chart_path> \
 --values <values_file_path> \
 --create-namespace \
 --namespace <namespace>
```

*For Example:*

```sh
$ helm install podinfo-app-dev ./ \
  --values values.yaml \
  --create-namespace \
  --namespace dev
```

### Accessing the Podinfo application

> [!NOTE]
>
> In this guide, I will focus on a simple NodePort service configuration to access the Podinfo application from the outside of the cluster for testing purposes only.
>
>  - If you want to use Ingress to access the Podinfo application with the domain name, you can enable it in the `.values.yaml` file [https://gitlab.com/thezawzaw/k8s-gitops-airnav-sample/-/blob/main/helm/podinfo-app/values.yaml](https://gitlab.com/thezawzaw/k8s-gitops-airnav-sample/-/blob/main/helm/podinfo-app/values.yaml#L63).
>  - For setting up the Ingress for more information can be found here: [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/); Or you can use the Gateway API [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/) to access the Podinfo app from the outside of the Kubernetes cluster.
>

A Kubernetes **NodePort** is a type of **Service** that enables access the application from the outside of the Kubernetes cluster. When you create a **Service** with the **NodePort Service** type, Kubernetes automatically assigns the static port with a range (30000-32767) on each Node in the cluster.

You have set up the NodePort Service type in the Podinfo Helm Chart. So, you can access the Podinfo application via **NodePort** from the outside of the Kubernetes cluster.

Please, see the **Service** configuration by the running the `kubectl get service` command. 

```sh
$ kubectl get service podinfo-app-dev --namespace sandbox
```

```sh
NAME                  TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
podinfo-app-dev   NodePort   10.43.175.76   <none>        80:30352/TCP   63d
```

To get the **NodePort** port number of the Podinfo Service, run the following `kubectl` command. In this example, NodePort is **`30352`**. *(Replace with your Service Name and Namespace.)*

```sh
$ kubectl describe service podinfo-app-dev --namespace sandbox
```

```sh
Name:                     podinfo-app-dev
Namespace:                sandbox
...
Type:                     NodePort
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.43.175.76
IPs:                      10.43.175.76
Port:                     http  80/TCP
TargetPort:               5005/TCP
NodePort:                 http  30352/TCP
...
```

To get the **Node IP address** your Kubernetes cluster, run the following `kubectl` command. In this example, the Node IP address is **`192.168.10.20`**.

```sh
$ kubectl get nodes -o wide
```

```sh
NAME                    STATUS   ROLES                  AGE   VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                      KERNEL-VERSION                 CONTAINER-RUNTIME
airnav-dev-k3s-server   Ready    control-plane,master   76d   v1.33.4+k3s1   192.168.10.20   <none>        AlmaLinux 9.6 (Sage Margay)   5.14.0-570.42.2.el9_6.x86_64   containerd://2.0.5-k3s2
```

Then, you can access the following URL in your web browser.

```sh
http://192.168.10.20:30352
```

![screenshot-podinfo-helm-demo](./images/img_screenshot_podinfo_k8s_demo.jpeg)

Now, you can see **Namespace**, **Node Name**, **Pod Name**, and **Pod IP** address information in the UI of the Podinfo application.

