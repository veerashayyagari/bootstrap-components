all:
	@echo "Usage:"
	@echo "  make create-cluster clustername=<cluster name>"
	@echo "  make test-ingress"	
	@echo "  make delete-cluster clustername=<cluster name>"

create-cluster:
	chmod +x ./setup-cluster.sh
	./setup-cluster.sh $(clustername)
	@echo "Done: creating local kind cluster. Setting up DNS"
	make setup-dns
	@echo "Done: Configuring DNS. Setting up Ingress"
	make setup-ingress

setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl --namespace ingress-nginx rollout status --timeout 5m deployment/ingress-nginx-controller

setup-dns:
	kubectl apply -f coredns.yaml
	kubectl -n kube-system rollout restart deployment/coredns
	kubectl -n kube-system rollout status --timeout 5m deployment/coredns

.PHONY: build-and-push
build-and-push:
	docker build ./test-ingress/sample-app -t localhost:5001/nodeweb:v1.1 -f ./test-ingress/Dockerfile
	docker push localhost:5001/nodeweb:v1.1

test-ingress: build-and-push
	kubectl apply -f ./test-ingress/deploy.yaml
	kubectl -n default rollout status --timeout 5m deployment/react-app-deployment
	kubectl -n default rollout status --timeout 5m deployment/httpbin-deployment

delete-cluster:
	kind delete cluster --name $(clustername)