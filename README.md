## Learning Tekton
Was actually part of Knative and was called Knative build and was extracted
into Tekton.

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

A task can emit string `results` which can be inspected, and can also be used
in Pipelines to pass data from one task to the next.

### TaskRun
Is a definition that when sent to kuberenetes will instantiate a specific task
and run it (in a pod).
For an example of a task see [task.yaml](src/taskrun.yaml)

So what component is responsible for actually running the task?


```console
$ kubectl api-resources 
NAME                              SHORTNAMES                             APIVERSION                             NAMESPACED   KIND
...
clustertasks                                                             tekton.dev/v1beta1                     false        ClusterTask
pipelineresources                                                        tekton.dev/v1alpha1                    true         PipelineResource
pipelineruns                      pr,prs                                 tekton.dev/v1beta1                     true         PipelineRun
pipelines                                                                tekton.dev/v1beta1                     true         Pipeline
runs                                                                     tekton.dev/v1alpha1                    true         Run
taskruns                          tr,trs                                 tekton.dev/v1beta1                     true         TaskRun
tasks                                                                    tekton.dev/v1beta1                     true         Task
```

### Pipeline
Is a collection of `Task`s and allow the tasks to be run an a specific order.
Each `Task` will execute as a Pod.

A pipeline must have at least one task in its `tasks` element which can either
be a `taskRef` or a `taskSpec`

### PipelineRun
Allows a pipeline to be instantiated and executed and does so by creating
TaskRuns for each task in the pipeline.

### Bundles
TODO:
 
## Tekton chains
Is also a CRD and is about secure supply chain security. This has a a controller
that "listens" for TaskRuns to complete and then takes a snapshot(?) and
converts this snapshot to a format which it then signs.

Taskruns and PipelineRuns can specify the outputs they produce using something
called chains [type hinting]. So a RunTask can specify a list results that it
produces. The Chains controller (I think) will scan/look for results with
the name `*_DIGEST` which should be in the format `alt:digest`.

```
spec:
  serviceAccountName: ""
  taskSpec:
    results:
    - name: TEST_URL
      type: string
    - name: TEST_DIGEST
      type: string
```


Install Tekton chains:
```console
$ make install-chains
kubectl apply --filename https://storage.googleapis.com/tekton-releases/chains/previous/v0.14.0/release.yaml
namespace/tekton-chains created
secret/signing-secrets created
configmap/chains-config created
deployment.apps/tekton-chains-controller created
clusterrolebinding.rbac.authorization.k8s.io/tekton-chains-controller-cluster-access created
clusterrole.rbac.authorization.k8s.io/tekton-chains-controller-cluster-access created
clusterrole.rbac.authorization.k8s.io/tekton-chains-controller-tenant-access created
clusterrolebinding.rbac.authorization.k8s.io/tekton-chains-controller-tenant-access created
serviceaccount/tekton-chains-controller created
role.rbac.authorization.k8s.io/tekton-chains-leader-election created
rolebinding.rbac.authorization.k8s.io/tekton-chains-controller-leaderelection created
role.rbac.authorization.k8s.io/tekton-chains-info created
rolebinding.rbac.authorization.k8s.io/tekton-chains-info created
configmap/chains-info created
configmap/config-logging created
```
Check that the installation worked:
```console
$ kubectl get po -n tekton-chains
NAME                                        READY   STATUS    RESTARTS   AGE
tekton-chains-controller-5bf5bfc478-p8gz7   1/1     Running   0          28s
```

To be able to sign artifacts we need to have a private key which we can use
cosign to generate for us:
```console
$ make cosign-keygen 
cosign generate-key-pair k8s://tekton-chains/signing-secrets
Enter password for private key: 
Enter password for private key again: 
Successfully created secret signing-secrets in namespace tekton-chains
Public key written to cosign.pub
```

Now, we can run a task which will then be signed by Tekton chains:
```console
$ make create-chain-taskrun 
kubectl apply -f src/chain.yaml 
taskrun.tekton.dev/tekton-chains-example configured
```

And we can inspect the result of this taskrun using:
```console
$ make describe-last-task 
tkn tr describe --last
Name:              tekton-chains-example
Namespace:         default
Service Account:   default
Timeout:           1h0m0s
Labels:
 app.kubernetes.io/managed-by=tekton-pipelines
Annotations:
 chains.tekton.dev/cert-taskrun-03f26b1e-50d0-402c-9b54-f22880b3893c=
 chains.tekton.dev/chain-taskrun-03f26b1e-50d0-402c-9b54-f22880b3893c=
 chains.tekton.dev/payload-taskrun-03f26b1e-50d0-402c-9b54-f22880b3893c=eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOm51bGwsInByZWRpY2F0ZSI6eyJidWlsZGVyIjp7ImlkIjoiaHR0cHM6Ly90ZWt0b24uZGV2L2NoYWlucy92MiJ9LCJidWlsZFR5cGUiOiJ0ZWt0b24uZGV2L3YxYmV0YTEvVGFza1J1biIsImludm9jYXRpb24iOnsiY29uZmlnU291cmNlIjp7fSwicGFyYW1ldGVycyI6e319LCJidWlsZENvbmZpZyI6eyJzdGVwcyI6W3siZW50cnlQb2ludCI6IiMhL3Vzci9iaW4vZW52IHNoXG5lY2hvICdnY3IuaW8vZm9vL2JhcicgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfVVJMXG5lY2hvIFwiZGFuYmV2LXRla3Rvbi1jaGFpbnMtZXhhbXBsZVwiIHwgc2hhMjU2c3VtIHwgdHIgLWQgJy0nIHwgdGVlIC90ZWt0b24vcmVzdWx0cy9URVNUX0RJR0VTVCIsImFyZ3VtZW50cyI6bnVsbCwiZW52aXJvbm1lbnQiOnsiY29udGFpbmVyIjoiY3JlYXRlLWltYWdlIiwiaW1hZ2UiOiJkb2NrZXIuaW8vbGlicmFyeS9idXN5Ym94QHNoYTI1NjpiNWQ2ZmUwNzEyNjM2Y2ViNzQzMDE4OWRlMjg4MTllMTk1ZTg5NjYzNzJlZGZjMmQ5NDA5ZDc5NDAyYTBkYzE2In0sImFubm90YXRpb25zIjpudWxsfV19LCJtZXRhZGF0YSI6eyJidWlsZFN0YXJ0ZWRPbiI6IjIwMjMtMDMtMjJUMTA6MDU6NTlaIiwiYnVpbGRGaW5pc2hlZE9uIjoiMjAyMy0wMy0yMlQxMDowNjowM1oiLCJjb21wbGV0ZW5lc3MiOnsicGFyYW1ldGVycyI6ZmFsc2UsImVudmlyb25tZW50IjpmYWxzZSwibWF0ZXJpYWxzIjpmYWxzZX0sInJlcHJvZHVjaWJsZSI6ZmFsc2V9fX0=
 chains.tekton.dev/signature-taskrun-03f26b1e-50d0-402c-9b54-f22880b3893c=eyJwYXlsb2FkVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5pbi10b3RvK2pzb24iLCJwYXlsb2FkIjoiZXlKZmRIbHdaU0k2SW1oMGRIQnpPaTh2YVc0dGRHOTBieTVwYnk5VGRHRjBaVzFsYm5RdmRqQXVNU0lzSW5CeVpXUnBZMkYwWlZSNWNHVWlPaUpvZEhSd2N6b3ZMM05zYzJFdVpHVjJMM0J5YjNabGJtRnVZMlV2ZGpBdU1pSXNJbk4xWW1wbFkzUWlPbTUxYkd3c0luQnlaV1JwWTJGMFpTSTZleUppZFdsc1pHVnlJanA3SW1sa0lqb2lhSFIwY0hNNkx5OTBaV3QwYjI0dVpHVjJMMk5vWVdsdWN5OTJNaUo5TENKaWRXbHNaRlI1Y0dVaU9pSjBaV3QwYjI0dVpHVjJMM1l4WW1WMFlURXZWR0Z6YTFKMWJpSXNJbWx1ZG05allYUnBiMjRpT25zaVkyOXVabWxuVTI5MWNtTmxJanA3ZlN3aWNHRnlZVzFsZEdWeWN5STZlMzE5TENKaWRXbHNaRU52Ym1acFp5STZleUp6ZEdWd2N5STZXM3NpWlc1MGNubFFiMmx1ZENJNklpTWhMM1Z6Y2k5aWFXNHZaVzUySUhOb1hHNWxZMmh2SUNkblkzSXVhVzh2Wm05dkwySmhjaWNnZkNCMFpXVWdMM1JsYTNSdmJpOXlaWE4xYkhSekwxUkZVMVJmVlZKTVhHNWxZMmh2SUZ3aVpHRnVZbVYyTFhSbGEzUnZiaTFqYUdGcGJuTXRaWGhoYlhCc1pWd2lJSHdnYzJoaE1qVTJjM1Z0SUh3Z2RISWdMV1FnSnkwbklId2dkR1ZsSUM5MFpXdDBiMjR2Y21WemRXeDBjeTlVUlZOVVgwUkpSMFZUVkNJc0ltRnlaM1Z0Wlc1MGN5STZiblZzYkN3aVpXNTJhWEp2Ym0xbGJuUWlPbnNpWTI5dWRHRnBibVZ5SWpvaVkzSmxZWFJsTFdsdFlXZGxJaXdpYVcxaFoyVWlPaUprYjJOclpYSXVhVzh2YkdsaWNtRnllUzlpZFhONVltOTRRSE5vWVRJMU5qcGlOV1EyWm1Vd056RXlOak0yWTJWaU56UXpNREU0T1dSbE1qZzRNVGxsTVRrMVpUZzVOall6TnpKbFpHWmpNbVE1TkRBNVpEYzVOREF5WVRCa1l6RTJJbjBzSW1GdWJtOTBZWFJwYjI1eklqcHVkV3hzZlYxOUxDSnRaWFJoWkdGMFlTSTZleUppZFdsc1pGTjBZWEowWldSUGJpSTZJakl3TWpNdE1ETXRNakpVTVRBNk1EVTZOVGxhSWl3aVluVnBiR1JHYVc1cGMyaGxaRTl1SWpvaU1qQXlNeTB3TXkweU1sUXhNRG93Tmpvd00xb2lMQ0pqYjIxd2JHVjBaVzVsYzNNaU9uc2ljR0Z5WVcxbGRHVnljeUk2Wm1Gc2MyVXNJbVZ1ZG1seWIyNXRaVzUwSWpwbVlXeHpaU3dpYldGMFpYSnBZV3h6SWpwbVlXeHpaWDBzSW5KbGNISnZaSFZqYVdKc1pTSTZabUZzYzJWOWZYMD0iLCJzaWduYXR1cmVzIjpbeyJrZXlpZCI6IlNIQTI1NjpjYUVKV1lKU3h5MVNWRjJLT2JtNVJyM1l0NnhJYjRUMnc1NkZIdENnOFdJIiwic2lnIjoiTUVZQ0lRRHNYK3ZFWmh1TG0zWlZ5ckNpVU9xSXVFbWFlZHFzdmFSc1NxZTRHQXVFVGdJaEFNd2ozeHN2WmgzTW5ZOFVDUHhWT2xoSzcrT0FWRXZsTzdsWVgyMnRycENtIn1dfQ==
 chains.tekton.dev/signed=true
 chains.tekton.dev/transparency=https://rekor.sigstore.dev/api/v1/log/entries?logIndex=16028007
 pipeline.tekton.dev/release=e38d112

🌡️  Status

STARTED         DURATION    STATUS
8 minutes ago   4s          Succeeded

📝 Results

 NAME            VALUE
 ∙ TEST_DIGEST   e952620d817ae0834ff59faf8716161407bb7342d813678d01d18779db82ab9c  
 ∙ TEST_URL      gcr.io/foo/bar

🦶 Steps

 NAME             STATUS
 ∙ create-image   Completed
```
Notice that there is a link to the Rekor log entry that was created. We will
use this later to get the public key.

Notice the `chains.tekton.dev/signature-taskrun-f96d34f5-b711-4378-8200-9c0b67265922`
annotation which contains a base64 encoded value:
```console
$ make show-dsse
eyJwYXlsb2FkVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5pbi10b3RvK2pzb24iLCJwYXlsb2FkIjoiZXlKZmRIbHdaU0k2SW1oMGRIQnpPaTh2YVc0dGRHOTBieTVwYnk5VGRHRjBaVzFsYm5RdmRqQXVNU0lzSW5CeVpXUnBZMkYwWlZSNWNHVWlPaUpvZEhSd2N6b3ZMM05zYzJFdVpHVjJMM0J5YjNabGJtRnVZMlV2ZGpBdU1pSXNJbk4xWW1wbFkzUWlPbTUxYkd3c0luQnlaV1JwWTJGMFpTSTZleUppZFdsc1pHVnlJanA3SW1sa0lqb2lhSFIwY0hNNkx5OTBaV3QwYjI0dVpHVjJMMk5vWVdsdWN5OTJNaUo5TENKaWRXbHNaRlI1Y0dVaU9pSjBaV3QwYjI0dVpHVjJMM1l4WW1WMFlURXZWR0Z6YTFKMWJpSXNJbWx1ZG05allYUnBiMjRpT25zaVkyOXVabWxuVTI5MWNtTmxJanA3ZlN3aWNHRnlZVzFsZEdWeWN5STZlMzE5TENKaWRXbHNaRU52Ym1acFp5STZleUp6ZEdWd2N5STZXM3NpWlc1MGNubFFiMmx1ZENJNklpTWhMM1Z6Y2k5aWFXNHZaVzUySUhOb1hHNWxZMmh2SUNkblkzSXVhVzh2Wm05dkwySmhjaWNnZkNCMFpXVWdMM1JsYTNSdmJpOXlaWE4xYkhSekwxUkZVMVJmVlZKTVhHNWxZMmh2SUZ3aVpHRnVZbVYyTFhSbGEzUnZiaTFqYUdGcGJuTXRaWGhoYlhCc1pWd2lJSHdnYzJoaE1qVTJjM1Z0SUh3Z2RISWdMV1FnSnkwbklId2dkR1ZsSUM5MFpXdDBiMjR2Y21WemRXeDBjeTlVUlZOVVgwUkpSMFZUVkNJc0ltRnlaM1Z0Wlc1MGN5STZiblZzYkN3aVpXNTJhWEp2Ym0xbGJuUWlPbnNpWTI5dWRHRnBibVZ5SWpvaVkzSmxZWFJsTFdsdFlXZGxJaXdpYVcxaFoyVWlPaUprYjJOclpYSXVhVzh2YkdsaWNtRnllUzlpZFhONVltOTRRSE5vWVRJMU5qcGlOV1EyWm1Vd056RXlOak0yWTJWaU56UXpNREU0T1dSbE1qZzRNVGxsTVRrMVpUZzVOall6TnpKbFpHWmpNbVE1TkRBNVpEYzVOREF5WVRCa1l6RTJJbjBzSW1GdWJtOTBZWFJwYjI1eklqcHVkV3hzZlYxOUxDSnRaWFJoWkdGMFlTSTZleUppZFdsc1pGTjBZWEowWldSUGJpSTZJakl3TWpNdE1ETXRNakpVTURrNk5UYzZNVFZhSWl3aVluVnBiR1JHYVc1cGMyaGxaRTl1SWpvaU1qQXlNeTB3TXkweU1sUXdPVG8xTnpveE9Wb2lMQ0pqYjIxd2JHVjBaVzVsYzNNaU9uc2ljR0Z5WVcxbGRHVnljeUk2Wm1Gc2MyVXNJbVZ1ZG1seWIyNXRaVzUwSWpwbVlXeHpaU3dpYldGMFpYSnBZV3h6SWpwbVlXeHpaWDBzSW5KbGNISnZaSFZqYVdKc1pTSTZabUZzYzJWOWZYMD0iLCJzaWduYXR1cmVzIjpbeyJrZXlpZCI6IlNIQTI1NjpjYUVKV1lKU3h5MVNWRjJLT2JtNVJyM1l0NnhJYjRUMnc1NkZIdENnOFdJIiwic2lnIjoiTUVRQ0lBU2p5cGttOFYvdVZKUVRuL3R0T0lZcjBDazUwQ0xmU2FnUWtTMTFleVIvQWlBM2VIUFlWWXJHbWNGaGx5Nlg5ZjE1YkRpbFVCZVh1UGo4ZzJ4NFNGQ0FEUT09In1dfQ==
```
Lets decode this and see what it contains:
```console
$ make show-dsse-base64-decode 
{
  "payloadType": "application/vnd.in-toto+json",
  "payload": "eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOm51bGwsInByZWRpY2F0ZSI6eyJidWlsZGVyIjp7ImlkIjoiaHR0cHM6Ly90ZWt0b24uZGV2L2NoYWlucy92MiJ9LCJidWlsZFR5cGUiOiJ0ZWt0b24uZGV2L3YxYmV0YTEvVGFza1J1biIsImludm9jYXRpb24iOnsiY29uZmlnU291cmNlIjp7fSwicGFyYW1ldGVycyI6e319LCJidWlsZENvbmZpZyI6eyJzdGVwcyI6W3siZW50cnlQb2ludCI6IiMhL3Vzci9iaW4vZW52IHNoXG5lY2hvICdnY3IuaW8vZm9vL2JhcicgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfVVJMXG5lY2hvIFwiZGFuYmV2LXRla3Rvbi1jaGFpbnMtZXhhbXBsZVwiIHwgc2hhMjU2c3VtIHwgdHIgLWQgJy0nIHwgdGVlIC90ZWt0b24vcmVzdWx0cy9URVNUX0RJR0VTVCIsImFyZ3VtZW50cyI6bnVsbCwiZW52aXJvbm1lbnQiOnsiY29udGFpbmVyIjoiY3JlYXRlLWltYWdlIiwiaW1hZ2UiOiJkb2NrZXIuaW8vbGlicmFyeS9idXN5Ym94QHNoYTI1NjpiNWQ2ZmUwNzEyNjM2Y2ViNzQzMDE4OWRlMjg4MTllMTk1ZTg5NjYzNzJlZGZjMmQ5NDA5ZDc5NDAyYTBkYzE2In0sImFubm90YXRpb25zIjpudWxsfV19LCJtZXRhZGF0YSI6eyJidWlsZFN0YXJ0ZWRPbiI6IjIwMjMtMDMtMjJUMDk6NTc6MTVaIiwiYnVpbGRGaW5pc2hlZE9uIjoiMjAyMy0wMy0yMlQwOTo1NzoxOVoiLCJjb21wbGV0ZW5lc3MiOnsicGFyYW1ldGVycyI6ZmFsc2UsImVudmlyb25tZW50IjpmYWxzZSwibWF0ZXJpYWxzIjpmYWxzZX0sInJlcHJvZHVjaWJsZSI6ZmFsc2V9fX0=",
  "signatures": [
    {
      "keyid": "SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI",
      "sig": "MEQCIASjypkm8V/uVJQTn/ttOIYr0Ck50CLfSagQkS11eyR/AiA3eHPYVYrGmcFhly6X9f15bDilUBeXuPj8g2x4SFCADQ=="
    }
  ]
}
```
Now this looks familiar. What we have here is an [Dead Simple Signing Envelope]
(DSSE).

<a id="keyid"></a>
The `keyid` is an identifier of the public key or certificate that can be used
to verify the signature. But how do we get the public key/certificate?  
So it is the signer who generates the keyid and it identifies both the algorithm
and key that was used to sign the message. So where is the keyid generated in
this case?

In the case of the tekton chains task it is generated in [wrap.go]:
```go
func Wrap(ctx context.Context, s Signer) (Signer, error) {
	pub, err := s.PublicKey()
	if err != nil {
		return nil, err
	}

	// Generate public key fingerprint
	sshpk, err := ssh.NewPublicKey(pub)
	if err != nil {
		return nil, err
	}
	fingerprint := ssh.FingerprintSHA256(sshpk)
```
And in [ssh.FingerprintSHA256] we have:
```go
// FingerprintSHA256 returns the user presentation of the key's
// fingerprint as unpadded base64 encoded sha256 hash.
// This format was introduced from OpenSSH 6.8.
// https://www.openssh.com/txt/release-6.8
// https://tools.ietf.org/html/rfc4648#section-3.2 (unpadded base64 encoding)
func FingerprintSHA256(pubKey PublicKey) string {
	sha256sum := sha256.Sum256(pubKey.Marshal())
	hash := base64.RawStdEncoding.EncodeToString(sha256sum[:])
	return "SHA256:" + hash
}
```

We can check use `ssh-keygen` to display the keyid for our public key using
the following commands:
```console
$ make get-public-keyid
kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq -r '."cosign.pub"' | base64 -d > public_key
ssh-keygen -f public_key -i -mPKCS8 > public_key_ssh 
ssh-keygen -e -l  -f public_key_ssh
256 SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI no comment (ECDSA)
tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2}" | base64 -d | jq '.signatures[].keyid'
"SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI"
```
The last line above is the keyid from the sigatures field in the example
envelope from above. Notice that they match:
```
256 SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI no comment (ECDSA)
    SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI"
```
We can inspect the public key in Rekor as well using:
```console
$ make public-key-from-rekor-log 
curl -s https://rekor.sigstore.dev/api/v1/log/entries?logIndex=16027962 | jq -r '.[].body' | base64 -d | jq -r '.spec.publicKey' | base64 -d
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEqiLuArRcZCY1s650rgKUDpj7f+b8
9HMu3K/PDaUcR9kcyyXY8q6U+TFTkc9u84wJTsZe21wBPd/STPEzo0JrzQ==
-----END PUBLIC KEY-----
```
We can manually inspect the log entry using the following:
https://rekor.tlog.dev/?uuid=24296fb24b8ad77ae0d13d8e6787e796456e52513fcb8a0bf77fd6f338a1575296bc8a9653e50007

Lets inspect the `payload`:
```console
$ make show-dsse-payload 
tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-f06f8151-3820-4966-a7a8-d10f0d7f064d}"  | base64 -d | jq -r '.payload' | base64 -d | jq
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": null,
  "predicate": {
    "builder": {
      "id": "https://tekton.dev/chains/v2"
    },
    "buildType": "tekton.dev/v1beta1/TaskRun",
    "invocation": {
      "configSource": {},
      "parameters": {}
    },
    "buildConfig": {
      "steps": [
        {
          "entryPoint": "#!/usr/bin/env sh\necho 'gcr.io/foo/bar' | tee /tekton/results/TEST_URL\necho \"danbev-tekton-chains-example\" | sha256sum | tr -d '-' | tee /tekton/results/TEST_DIGEST",
          "arguments": null,
          "environment": {
            "container": "create-image",
            "image": "docker.io/library/busybox@sha256:b5d6fe0712636ceb7430189de28819e195e8966372edfc2d9409d79402a0dc16"
          },
          "annotations": null
        }
      ]
    },
    "metadata": {
      "buildStartedOn": "2023-03-22T09:57:15Z",
      "buildFinishedOn": "2023-03-22T09:57:19Z",
      "completeness": {
        "parameters": false,
        "environment": false,
        "materials": false
      },
      "reproducible": false
    }
  }
}
```
And from this we can see that the payload contains a SLSA Provenance predicate,
in this case [SLSA v2]. The `builder` specifies the entity that produced this
the software artifacts. The `invocation` is what the builder uses as its
configuration, and the `buildConfig` is what the builder performed.
See [schema] for all the available fields.

And we can verify using:
```console
$ make verify-signature 
cosign verify-blob -d --key k8s://tekton-chains/signing-secrets --signature attestation attestation
Verified OK
```

### keyid lookup in Rekor
Let say we have an attestation envelope and one of the signatures entries
contains a keyid and a sig field. If we want to lookup the public key in Rekor
for this keyid, how would we do that?

We can hash the payload of the envelope:
```console
$ tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-03f26b1e-50d0-402c-9b54-f22880b3893c}" | base64 -d | jq -r '.payload' | base64 -d | sha256sum
39e86413a7f13a1e20d1bb915df4fab8a58677e78a6b335bb2e614be8bef1dc8  -
```
And then use that hash to lookup the the entry using:
```console
$ rekor-cli search --sha 39e86413a7f13a1e20d1bb915df4fab8a58677e78a6b335bb2e614be8bef1dc8
Found matching entries (listed by UUID):
24296fb24b8ad77a27dbac48342e32d86ca2e056106ff7e94cd4a6ed2a12de00b7ffc57fc2f2c2e4
24296fb24b8ad77ae0d13d8e6787e796456e52513fcb8a0bf77fd6f338a1575296bc8a9653e50007
```
And the we can use the following command to look up one of those entries
to get the public key:
```console
$ rekor-cli get --uuid 24296fb24b8ad77a27dbac48342e32d86ca2e056106ff7e94cd4a6ed2a12de00b7ffc57fc2f2c2e4
LogID: c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d
Attestation: {"_type":"https://in-toto.io/Statement/v0.1","predicateType":"https://slsa.dev/provenance/v0.2","subject":null,"predicate":{"builder":{"id":"https://tekton.dev/chains/v2"},"buildType":"tekton.dev/v1beta1/TaskRun","invocation":{"configSource":{},"parameters":{}},"buildConfig":{"steps":[{"entryPoint":"#!/usr/bin/env sh\necho 'gcr.io/foo/bar' | tee /tekton/results/TEST_URL\necho \"danbev-tekton-chains-example\" | sha256sum | tr -d '-' | tee /tekton/results/TEST_DIGEST","arguments":null,"environment":{"container":"create-image","image":"docker.io/library/busybox@sha256:b5d6fe0712636ceb7430189de28819e195e8966372edfc2d9409d79402a0dc16"},"annotations":null}]},"metadata":{"buildStartedOn":"2023-03-22T10:05:59Z","buildFinishedOn":"2023-03-22T10:06:03Z","completeness":{"parameters":false,"environment":false,"materials":false},"reproducible":false}}}
Index: 16028007
IntegratedTime: 2023-03-22T10:06:31Z
UUID: 24296fb24b8ad77a27dbac48342e32d86ca2e056106ff7e94cd4a6ed2a12de00b7ffc57fc2f2c2e4
Body: {
  "IntotoObj": {
    "content": {
      "hash": {
        "algorithm": "sha256",
        "value": "13ce08f7ba256f394700b6ee68afcf85dc06c438587551319d3e150a247de0a1"
      },
      "payloadHash": {
        "algorithm": "sha256",
        "value": "39e86413a7f13a1e20d1bb915df4fab8a58677e78a6b335bb2e614be8bef1dc8"
      }
    },
    "publicKey": "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFcWlMdUFyUmNaQ1kxczY1MHJnS1VEcGo3ZitiOAo5SE11M0svUERhVWNSOWtjeXlYWThxNlUrVEZUa2M5dTg0d0pUc1plMjF3QlBkL1NUUEV6bzBKcnpRPT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg=="
  }
}
```
We could calculate the fingerprint of the `publicKey` and compare it to the
keyid and if they are the same we know that this public key matches the keyid.


[in-toto attestation]: https://github.com/danbev/learning-crypto/blob/main/notes/in-toto-attestations.md#in-toto-attestation
[type hinting]: https://tekton.dev/docs/chains/intoto/#type-hinting
[Dead Simple Signing Envelope]: https://github.com/danbev/learning-crypto/blob/main/notes/dsse.md
[SLSA v2]: https://slsa.dev/provenance/v0.2
[schema]: https://slsa.dev/provenance/v0.2#schema
[wrap.go]: https://github.com/tektoncd/chains/blob/eb7cc9f590474c9633956cf7c293028b2db5a61a/pkg/chains/signing/wrap.go#L42
[ssh.FingerprintSHA256]: https://cs.opensource.google/go/x/crypto/+/master:ssh/keys.go;l=1443?q=FingerprintSHA256&ss=go%2Fx%2Fcrypto
