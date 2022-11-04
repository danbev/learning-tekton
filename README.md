## Learning Tekton


### Install Tekton
Since Tekton runs on Kubernetes we need install Tekton to Kubernetes. In this
case I'll use minishift which needs to be started first. After that we can
install a Tekton [release](https://github.com/tektoncd/pipeline/releases)]:
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

There is also a command line tool named
[tkn](https://github.com/tektoncd/cli#linux-rpms) which should be installed:
```console
$ tkn version
Client version: 0.27.0
Pipeline version: v0.41.0
```

### Running
```console
$ cd hello-world
$ kubectl apply -f task.yaml 
task.tekton.dev/hello created
```

```console
$ kubectl get task
NAME    AGE
hello   9s
```

We can get more information about this task using `tkn`: 
```console
$ tkn task describe hello
Name:        hello
Namespace:   default

🦶 Steps

 ∙ print-something
```
And we can run this task using:
```console
$ tkn task start --showlog hello
TaskRun started: hello-run-v2v9d
Waiting for logs to be available...
[print-something] bajja
```
