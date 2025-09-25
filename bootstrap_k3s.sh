#!/usr/bin/env bash

#
# A Shell Script
# to setup and bootstrap the K3s server, also known as Kubernetes control-plane/master node
#
# This script is for setup the single-node K3s Kubernetes cluster.
#

curl -sfL https://get.k3s.io | sh -s - server \
	--disable traefik \
	--write-kubeconfig-mode 644

