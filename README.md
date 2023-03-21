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
 chains.tekton.dev/cert-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2=
 chains.tekton.dev/chain-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2=
 chains.tekton.dev/payload-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2=eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOm51bGwsInByZWRpY2F0ZSI6eyJidWlsZGVyIjp7ImlkIjoiaHR0cHM6Ly90ZWt0b24uZGV2L2NoYWlucy92MiJ9LCJidWlsZFR5cGUiOiJ0ZWt0b24uZGV2L3YxYmV0YTEvVGFza1J1biIsImludm9jYXRpb24iOnsiY29uZmlnU291cmNlIjp7fSwicGFyYW1ldGVycyI6e319LCJidWlsZENvbmZpZyI6eyJzdGVwcyI6W3siZW50cnlQb2ludCI6IiMhL3Vzci9iaW4vZW52IHNoXG5lY2hvICdnY3IuaW8vZm9vL2JhcicgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfVVJMXG5lY2hvICdzaGEyNTY6MDVmOTViMjZlZDEwNjY4YjcxODNjMWUyZGE5ODYxMGU5MTM3MmZhOWY1MTAwNDZkNGNlNTgxMmFkZGFkODZiNScgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfRElHRVNUIiwiYXJndW1lbnRzIjpudWxsLCJlbnZpcm9ubWVudCI6eyJjb250YWluZXIiOiJjcmVhdGUtaW1hZ2UiLCJpbWFnZSI6ImRvY2tlci5pby9saWJyYXJ5L2J1c3lib3hAc2hhMjU2OmMxMThmNTM4MzY1MzY5MjA3YzEyZTU3OTRjM2NiZmI3YjA0MmQ5NTBhZjU5MGFlNmMyODdlZGU3NGYyOWI3ZDQifSwiYW5ub3RhdGlvbnMiOm51bGx9XX0sIm1ldGFkYXRhIjp7ImJ1aWxkU3RhcnRlZE9uIjoiMjAyMy0wMy0xMlQwOTo0MDoxNloiLCJidWlsZEZpbmlzaGVkT24iOiIyMDIzLTAzLTEyVDA5OjQwOjIxWiIsImNvbXBsZXRlbmVzcyI6eyJwYXJhbWV0ZXJzIjpmYWxzZSwiZW52aXJvbm1lbnQiOmZhbHNlLCJtYXRlcmlhbHMiOmZhbHNlfSwicmVwcm9kdWNpYmxlIjpmYWxzZX19fQ==
 chains.tekton.dev/signature-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2=eyJwYXlsb2FkVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5pbi10b3RvK2pzb24iLCJwYXlsb2FkIjoiZXlKZmRIbHdaU0k2SW1oMGRIQnpPaTh2YVc0dGRHOTBieTVwYnk5VGRHRjBaVzFsYm5RdmRqQXVNU0lzSW5CeVpXUnBZMkYwWlZSNWNHVWlPaUpvZEhSd2N6b3ZMM05zYzJFdVpHVjJMM0J5YjNabGJtRnVZMlV2ZGpBdU1pSXNJbk4xWW1wbFkzUWlPbTUxYkd3c0luQnlaV1JwWTJGMFpTSTZleUppZFdsc1pHVnlJanA3SW1sa0lqb2lhSFIwY0hNNkx5OTBaV3QwYjI0dVpHVjJMMk5vWVdsdWN5OTJNaUo5TENKaWRXbHNaRlI1Y0dVaU9pSjBaV3QwYjI0dVpHVjJMM1l4WW1WMFlURXZWR0Z6YTFKMWJpSXNJbWx1ZG05allYUnBiMjRpT25zaVkyOXVabWxuVTI5MWNtTmxJanA3ZlN3aWNHRnlZVzFsZEdWeWN5STZlMzE5TENKaWRXbHNaRU52Ym1acFp5STZleUp6ZEdWd2N5STZXM3NpWlc1MGNubFFiMmx1ZENJNklpTWhMM1Z6Y2k5aWFXNHZaVzUySUhOb1hHNWxZMmh2SUNkblkzSXVhVzh2Wm05dkwySmhjaWNnZkNCMFpXVWdMM1JsYTNSdmJpOXlaWE4xYkhSekwxUkZVMVJmVlZKTVhHNWxZMmh2SUNkemFHRXlOVFk2TURWbU9UVmlNalpsWkRFd05qWTRZamN4T0ROak1XVXlaR0U1T0RZeE1HVTVNVE0zTW1aaE9XWTFNVEF3TkRaa05HTmxOVGd4TW1Ga1pHRmtPRFppTlNjZ2ZDQjBaV1VnTDNSbGEzUnZiaTl5WlhOMWJIUnpMMVJGVTFSZlJFbEhSVk5VSWl3aVlYSm5kVzFsYm5SeklqcHVkV3hzTENKbGJuWnBjbTl1YldWdWRDSTZleUpqYjI1MFlXbHVaWElpT2lKamNtVmhkR1V0YVcxaFoyVWlMQ0pwYldGblpTSTZJbVJ2WTJ0bGNpNXBieTlzYVdKeVlYSjVMMkoxYzNsaWIzaEFjMmhoTWpVMk9tTXhNVGhtTlRNNE16WTFNelk1TWpBM1l6RXlaVFUzT1RSak0yTmlabUkzWWpBME1tUTVOVEJoWmpVNU1HRmxObU15T0RkbFpHVTNOR1l5T1dJM1pEUWlmU3dpWVc1dWIzUmhkR2x2Ym5NaU9tNTFiR3g5WFgwc0ltMWxkR0ZrWVhSaElqcDdJbUoxYVd4a1UzUmhjblJsWkU5dUlqb2lNakF5TXkwd015MHhNbFF3T1RvME1Eb3hObG9pTENKaWRXbHNaRVpwYm1semFHVmtUMjRpT2lJeU1ESXpMVEF6TFRFeVZEQTVPalF3T2pJeFdpSXNJbU52YlhCc1pYUmxibVZ6Y3lJNmV5SndZWEpoYldWMFpYSnpJanBtWVd4elpTd2laVzUyYVhKdmJtMWxiblFpT21aaGJITmxMQ0p0WVhSbGNtbGhiSE1pT21aaGJITmxmU3dpY21Wd2NtOWtkV05wWW14bElqcG1ZV3h6WlgxOWZRPT0iLCJzaWduYXR1cmVzIjpbeyJrZXlpZCI6IlNIQTI1NjpjYUVKV1lKU3h5MVNWRjJLT2JtNVJyM1l0NnhJYjRUMnc1NkZIdENnOFdJIiwic2lnIjoiTUVRQ0lDdXZnMFhxd0NFQ0V5U2tvSG1zVEora3RXOUlTekdYc3AzR1FEYUJTYW02QWlBai9nKzNkdUR0RUk5dWQ0YUYvRmI0dzl5NW9nN1VOcm1PNXQ5VHhVZlZydz09In1dfQ==
 chains.tekton.dev/signed=true
 pipeline.tekton.dev/release=e38d112

🌡️  Status

STARTED         DURATION    STATUS
4 minutes ago   5s          Succeeded

📝 Results

 NAME            VALUE
 ∙ TEST_DIGEST   sha256:05f95b26ed10668b7183c1e2da98610e91372fa9f510046d4ce5812addad86b5
 ∙ TEST_URL      gcr.io/foo/bar

🦶 Steps

 NAME             STATUS
 ∙ create-image   Completed

```
Notice the `chains.tekton.dev/signature-taskrun-f96d34f5-b711-4378-8200-9c0b67265922`
annotation which contains a base64 encoded value:
```console
$ make show-dsse
eyJwYXlsb2FkVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5pbi10b3RvK2pzb24iLCJwYXlsb2FkIjoiZXlKZmRIbHdaU0k2SW1oMGRIQnpPaTh2YVc0dGRHOTBieTVwYnk5VGRHRjBaVzFsYm5RdmRqQXVNU0lzSW5CeVpXUnBZMkYwWlZSNWNHVWlPaUpvZEhSd2N6b3ZMM05zYzJFdVpHVjJMM0J5YjNabGJtRnVZMlV2ZGpBdU1pSXNJbk4xWW1wbFkzUWlPbTUxYkd3c0luQnlaV1JwWTJGMFpTSTZleUppZFdsc1pHVnlJanA3SW1sa0lqb2lhSFIwY0hNNkx5OTBaV3QwYjI0dVpHVjJMMk5vWVdsdWN5OTJNaUo5TENKaWRXbHNaRlI1Y0dVaU9pSjBaV3QwYjI0dVpHVjJMM1l4WW1WMFlURXZWR0Z6YTFKMWJpSXNJbWx1ZG05allYUnBiMjRpT25zaVkyOXVabWxuVTI5MWNtTmxJanA3ZlN3aWNHRnlZVzFsZEdWeWN5STZlMzE5TENKaWRXbHNaRU52Ym1acFp5STZleUp6ZEdWd2N5STZXM3NpWlc1MGNubFFiMmx1ZENJNklpTWhMM1Z6Y2k5aWFXNHZaVzUySUhOb1hHNWxZMmh2SUNkblkzSXVhVzh2Wm05dkwySmhjaWNnZkNCMFpXVWdMM1JsYTNSdmJpOXlaWE4xYkhSekwxUkZVMVJmVlZKTVhHNWxZMmh2SUNkemFHRXlOVFk2TURWbU9UVmlNalpsWkRFd05qWTRZamN4T0ROak1XVXlaR0U1T0RZeE1HVTVNVE0zTW1aaE9XWTFNVEF3TkRaa05HTmxOVGd4TW1Ga1pHRmtPRFppTlNjZ2ZDQjBaV1VnTDNSbGEzUnZiaTl5WlhOMWJIUnpMMVJGVTFSZlJFbEhSVk5VSWl3aVlYSm5kVzFsYm5SeklqcHVkV3hzTENKbGJuWnBjbTl1YldWdWRDSTZleUpqYjI1MFlXbHVaWElpT2lKamNtVmhkR1V0YVcxaFoyVWlMQ0pwYldGblpTSTZJbVJ2WTJ0bGNpNXBieTlzYVdKeVlYSjVMMkoxYzNsaWIzaEFjMmhoTWpVMk9tTXhNVGhtTlRNNE16WTFNelk1TWpBM1l6RXlaVFUzT1RSak0yTmlabUkzWWpBME1tUTVOVEJoWmpVNU1HRmxObU15T0RkbFpHVTNOR1l5T1dJM1pEUWlmU3dpWVc1dWIzUmhkR2x2Ym5NaU9tNTFiR3g5WFgwc0ltMWxkR0ZrWVhSaElqcDdJbUoxYVd4a1UzUmhjblJsWkU5dUlqb2lNakF5TXkwd015MHhNbFF3T1RvME1Eb3hObG9pTENKaWRXbHNaRVpwYm1semFHVmtUMjRpT2lJeU1ESXpMVEF6TFRFeVZEQTVPalF3T2pJeFdpSXNJbU52YlhCc1pYUmxibVZ6Y3lJNmV5SndZWEpoYldWMFpYSnpJanBtWVd4elpTd2laVzUyYVhKdmJtMWxiblFpT21aaGJITmxMQ0p0WVhSbGNtbGhiSE1pT21aaGJITmxmU3dpY21Wd2NtOWtkV05wWW14bElqcG1ZV3h6WlgxOWZRPT0iLCJzaWduYXR1cmVzIjpbeyJrZXlpZCI6IlNIQTI1NjpjYUVKV1lKU3h5MVNWRjJLT2JtNVJyM1l0NnhJYjRUMnc1NkZIdENnOFdJIiwic2lnIjoiTUVRQ0lDdXZnMFhxd0NFQ0V5U2tvSG1zVEora3RXOUlTekdYc3AzR1FEYUJTYW02QWlBai9nKzNkdUR0RUk5dWQ0YUYvRmI0dzl5NW9nN1VOcm1PNXQ5VHhVZlZydz09In1dfQ==
```
Lets decode this and see what it contains:
```console
$ make show-dsse-base64-decode 
{
  "payloadType": "application/vnd.in-toto+json",
  "payload": "eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOm51bGwsInByZWRpY2F0ZSI6eyJidWlsZGVyIjp7ImlkIjoiaHR0cHM6Ly90ZWt0b24uZGV2L2NoYWlucy92MiJ9LCJidWlsZFR5cGUiOiJ0ZWt0b24uZGV2L3YxYmV0YTEvVGFza1J1biIsImludm9jYXRpb24iOnsiY29uZmlnU291cmNlIjp7fSwicGFyYW1ldGVycyI6e319LCJidWlsZENvbmZpZyI6eyJzdGVwcyI6W3siZW50cnlQb2ludCI6IiMhL3Vzci9iaW4vZW52IHNoXG5lY2hvICdnY3IuaW8vZm9vL2JhcicgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfVVJMXG5lY2hvICdzaGEyNTY6MDVmOTViMjZlZDEwNjY4YjcxODNjMWUyZGE5ODYxMGU5MTM3MmZhOWY1MTAwNDZkNGNlNTgxMmFkZGFkODZiNScgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL1RFU1RfRElHRVNUIiwiYXJndW1lbnRzIjpudWxsLCJlbnZpcm9ubWVudCI6eyJjb250YWluZXIiOiJjcmVhdGUtaW1hZ2UiLCJpbWFnZSI6ImRvY2tlci5pby9saWJyYXJ5L2J1c3lib3hAc2hhMjU2OmMxMThmNTM4MzY1MzY5MjA3YzEyZTU3OTRjM2NiZmI3YjA0MmQ5NTBhZjU5MGFlNmMyODdlZGU3NGYyOWI3ZDQifSwiYW5ub3RhdGlvbnMiOm51bGx9XX0sIm1ldGFkYXRhIjp7ImJ1aWxkU3RhcnRlZE9uIjoiMjAyMy0wMy0xMlQwOTo0MDoxNloiLCJidWlsZEZpbmlzaGVkT24iOiIyMDIzLTAzLTEyVDA5OjQwOjIxWiIsImNvbXBsZXRlbmVzcyI6eyJwYXJhbWV0ZXJzIjpmYWxzZSwiZW52aXJvbm1lbnQiOmZhbHNlLCJtYXRlcmlhbHMiOmZhbHNlfSwicmVwcm9kdWNpYmxlIjpmYWxzZX19fQ==",
  "signatures": [
    {
      "keyid": "SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI",
      "sig": "MEQCICuvg0XqwCECEySkoHmsTJ+ktW9ISzGXsp3GQDaBSam6AiAj/g+3duDtEI9ud4aF/Fb4w9y5og7UNrmO5t9TxUfVrw=="
    }
  ]
}
```
Now this looks familiar. What we have here is an [Dead Simple Signing Envelope]
(DSSE).

<a id="keyid" />
The `keyid` is an identifier of the public key or certificate that can be used
to verify the signature. But how do we get the public key/certificate?  
So it is the signer who generates the keyid and it identifies both the algorithm
and key that was used to sign the message. So where is the keyid generated in
this case?
In the case or the tekton chains task it is generated in [wrap.go] and follows
the [Public Key Fingerprints]. We can see this using:
```console
$ make get-public-keyid 
kubectl get secret signing-secrets -n tekton-chains -o jsonpath='{.data}' | jq -r '."cosign.pub"' | base64 -d
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEqiLuArRcZCY1s650rgKUDpj7f+b8
9HMu3K/PDaUcR9kcyyXY8q6U+TFTkc9u84wJTsZe21wBPd/STPEzo0JrzQ==
-----END PUBLIC KEY-----
```

Lets inspect the `payload`:
```console
$ make show-dsse-payload
tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-dc37cde4-4d57-47eb-9e10-67153e440db2}"  | base64 -d | jq -r '.payload' | base64 -d | jq
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
          "entryPoint": "#!/usr/bin/env sh\necho 'gcr.io/foo/bar' | tee /tekton/results/TEST_URL\necho 'sha256:05f95b26ed10668b7183c1e2da98610e91372fa9f510046d4ce5812addad86b5' | tee /tekton/results/TEST_DIGEST",
          "arguments": null,
          "environment": {
            "container": "create-image",
            "image": "docker.io/library/busybox@sha256:c118f538365369207c12e5794c3cbfb7b042d950af590ae6c287ede74f29b7d4"
          },
          "annotations": null
        }
      ]
    },
    "metadata": {
      "buildStartedOn": "2023-03-12T09:40:16Z",
      "buildFinishedOn": "2023-03-12T09:40:21Z",
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

[in-toto attestation]: https://github.com/danbev/learning-crypto/blob/main/notes/in-toto-attestations.md#in-toto-attestation
[type hinting]: https://tekton.dev/docs/chains/intoto/#type-hinting
[Dead Simple Signing Envelope]: https://github.com/danbev/learning-crypto/blob/main/notes/dsse.md
[SLSA v2]: https://slsa.dev/provenance/v0.2
[schema]: https://slsa.dev/provenance/v0.2#schema
[Public Key Fingerprints]: https://www.rfc-editor.org/rfc/rfc4716#section-4
[wrap.go]: https://github.com/tektoncd/chains/blob/eb7cc9f590474c9633956cf7c293028b2db5a61a/pkg/chains/signing/wrap.go
