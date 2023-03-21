create-cluster:
	kind create cluster -n tekton-exploration

install-tekton:
	kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.41.0/release.yaml

check-tekton-pods:
	kubectl get pods --namespace tekton-pipelines --watch

create-task:
	kubectl apply -f src/task.yaml 

create-taskrun:
	kubectl apply -f src/taskrun.yaml 

log:
	kubectl logs basic-task-run-pod

task-describe:
	kubectl describe task

taskrun-describe:
	kubectl describe taskrun

get-task:
	kubectl get task

clean:
	kubectl delete -f src/task.yaml
	kubectl delete -f src/taskrun.yaml
	kubectl delete -f src/chain.yaml

install-chains:
	kubectl apply --filename https://storage.googleapis.com/tekton-releases/chains/previous/v0.14.0/release.yaml

cosign-keygen:
	cosign generate-key-pair k8s://tekton-chains/signing-secrets

configure-chains:
	kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.oci.storage": "", "artifacts.taskrun.format":"in-toto", "artifacts.taskrun.storage": "tekton"}}'

show-chains-configmap:
	kubectl get configmap -n tekton-chains

restart-chains:
	kubectl delete po -n tekton-chains -l app=tekton-chains-controller

deploy-chain-taskrun:
	kubectl delete -f src/chain.yaml 
	kubectl apply -f src/chain.yaml 

describe-last-task:
	tkn tr describe --last

show-dsse:
	@tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}"

show-dsse-base64-decode:
	@tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}" | base64 -d | jq

show-dsse-payload:
	tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}"  | base64 -d | jq -r '.payload' | base64 -d | jq

save-dsse:
	@tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}" | base64 -d > attestation
	@echo "saved attestation"

verify-signature: save-dsse
	cosign verify-blob -d --key k8s://tekton-chains/signing-secrets --signature attestation attestation

list-secretes:
	kubectl describe secret -n tekton-chains

show-secretes:
	kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq

get-public-key:
	kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq -r '."cosign.pub"'

