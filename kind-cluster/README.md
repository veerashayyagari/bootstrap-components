# Kind : Local k8s cluster with Ingress and Registry support

*Instructions are specific to MacOS Apple Silicon, should work on other OS once the appropriate pre-requisites are installed*

## Prerequisites

- [Optional] Install [Homebrew](https://brew.sh/)
- Install [Docker](https://docs.docker.com/get-docker/) on your machine
- Install [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)

    ```
    # if you have homebrew installed
    brew install kubectl
    ```

- Install [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

    ```
    # if you have homebrew installed
    brew install kind
    ```

## Installation

- Run `make create-cluster`
- creates a multi-node cluster with ingress controller that also hosts local-registry

### Basic Validation

- `kind get clusters` , should list cluster with name 'kind-k8s-cluster'
- `curl -v http://localhost:5001` , should return 200 Ok
- `kubectl config set-context kind-k8s-cluster` should switch kube context to the k8s-cluster ( *Note: you have to prefix 'kind-' to the actual cluster name you created* )
- `kubectl get nodes`, should return multi node local cluster with ingress controller

![Validation](./images/cluster-setup-validation.png)

### Registry Validation

- Currently (as of Jan 1st 2023), kind cluster doesn't automatically load images from docker registry.

- Option 1 : using `kind load docker-image` and push the image to the corresponding node(s)

- Option 2 : Push the image to the local registry and use the image with the registry tag to load images into the cluster
  - Let's tag a local image 'na:local' against the registry we just setup
    ```
    docker tag na:local localhost:5001/na:local

    docker push localhost:5001/na:local
    ```
