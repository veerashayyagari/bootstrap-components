all:
	@echo "Usage:"
	@echo "  make create-cluster"	

create-cluster:
	chmod +x ./setup-cluster.sh
	./setup-cluster.sh
	@echo "Done: creating local kind cluster"
	make setup-ingress

setup-local-registry:
	chmod +x ./setup-local-registry.sh
	./setup-local-registry.sh

setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl --namespace ingress-nginx rollout status --timeout 5m deployment/ingress-nginx-controller
