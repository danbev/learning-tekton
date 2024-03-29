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
	kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"transparency.enabled": "true"}}'

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
	tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}" | base64 -d | jq

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
	kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq -r '."cosign.pub"' | base64 -d

get-public-keyid:
	kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq -r '."cosign.pub"' | base64 -d > public_key
	ssh-keygen -f public_key -i -mPKCS8 > public_key_ssh 
	ssh-keygen -e -l  -f public_key_ssh
	tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-$(shell tkn tr describe --last -o  jsonpath='{.metadata.uid}')}" | base64 -d | jq '.signatures[].keyid'

show-rekor-log:
	curl -s https://rekor.sigstore.dev/api/v1/log/entries?logIndex=16027962 | jq -r '.[].body' | base64 -d | jq

public-key-from-rekor-log:
	curl -s https://rekor.sigstore.dev/api/v1/log/entries?logIndex=16027962 | jq -r '.[].body' | base64 -d | jq -r '.spec.publicKey' | base64 -d

rekor-lookup-hash:
	rekor-cli search --sha 39e86413a7f13a1e20d1bb915df4fab8a58677e78a6b335bb2e614be8bef1dc8
	rekor-cli get --uuid 24296fb24b8ad77a27dbac48342e32d86ca2e056106ff7e94cd4a6ed2a12de00b7ffc57fc2f2c2e4 --format json | jq


