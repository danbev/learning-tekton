## Learning Tekton

### Install Tekton
Since Tekton runs on Kubernetes we need install Tekton to Kubernetes. In this
case I'll use [kind](https://www.baeldung.com/ops/kubernetes-kind) which needs
to be installed and started started first:
```console
$ curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
$ chmod +x ./kind
$ sudo mv ./kind /usr/local/bin/kind
$ kind version
kind v0.17.0 go1.19.2 linux/amd64
```

Next, we need to create a cluster to work with:
```console
$ kind create cluster -n tekton-exploration
kind create cluster -n tekton-exploration
Creating cluster "tekton-exploration" ...
 ✓ Ensuring node image (kindest/node:v1.25.3) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-tekton-exploration"
You can now use your cluster with:

kubectl cluster-info --context kind-tekton-exploration

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

After that we can
install a Tekton [release](https://github.com/tektoncd/pipeline/releases):
```console
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.41.0/release.yaml
```

A `tekton-piplines` namespace will be created and we can check that the pods
start up as expected using:
```console
$ kubectl get pods --namespace tekton-pipelines --watch
NAME                                           READY   STATUS              RESTARTS   AGE
tekton-pipelines-controller-6b8469ffbb-v454c   0/1     Running             0          14s
tekton-pipelines-webhook-67d85bc5c8-6phh6      0/1     ContainerCreating   0          13s
tekton-pipelines-controller-6b8469ffbb-v454c   1/1     Running             0          20s
tekton-pipelines-webhook-67d85bc5c8-6phh6      0/1     Running             0          20s
tekton-pipelines-webhook-67d85bc5c8-6phh6      1/1     Running             0          30s
```

### Running
Deploy the task definition:
```console
$ kubectl apply -f task.yaml 
task.tekton.dev/hello created
```

```console
$ kubectl get task
NAME    AGE
hello   9s
```

And we can run this task using:
```console
$ kubectl apply -f src/taskrun.yaml 
```

And we can inspect the log output of the pod that was created for by the
taskrun controller (I think):
```
$ make log
kubectl logs basic-task-run-pod
Defaulted container "step-print-command" out of: step-print-command, step-print-script, prepare (init), place-scripts (init)
[basic-task]: bajja
```

### Task
Is a collection of one or more steps to be executed.
For an example of a task see [task.yaml](src/task.yaml)

### TaskRun
Is a definition that when sent to kuberenetes will instantiate a specific task
and run it (in a pod).
For an example of a task see [task.yaml](src/taskrun.yaml)
 
