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
