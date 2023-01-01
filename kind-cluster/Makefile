all:
	@echo "Usage:"
	@echo "  make create-cluster"	

create-cluster:
	make setup-local-registry
	@echo "Done: local registry setup"
	kind create cluster --name k8s-cluster --config kind-cluster.yaml
	@echo "Done: creating local kind cluster"
	make setup-ingress

setup-local-registry:
	#!/bin/sh
	set -o errexit

	# create registry container unless it already exists
	reg_name='kind-registry'
	reg_port='50001'
	cluster_port='5000'
	if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
	docker run \
		-d --restart=always -p "127.0.0.1:${reg_port}:${cluster_port}" --name "${reg_name}" \
		registry:2
	fi

	# create a cluster with the local registry enabled in containerd
	cat <<EOF | kind create cluster --config=-
	kind: Cluster
	apiVersion: kind.x-k8s.io/v1alpha4
	containerdConfigPatches:
	- |-
	[plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
		endpoint = ["http://${reg_name}:${cluster_port}"]
	EOF

	# connect the registry to the cluster network if not already connected
	if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
	docker network connect "kind" "${reg_name}"
	fi

	# Document the local registry
	# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
	cat <<EOF | kubectl apply -f -
	apiVersion: v1
	kind: ConfigMap
	metadata:
	name: local-registry-hosting
	namespace: kube-public
	data:
	localRegistryHosting.v1: |
		host: "localhost:${reg_port}"
		help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
	EOF

setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl --namespace ingress-nginx rollout status --timeout 90s deployment/ingress-nginx-controller
