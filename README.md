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
 
## Tekton chains
Is also a CRD and is about secure supply chain security. This has a a controller
that "listens" for TaskRuns to complete and then takes a snapshot(?) and
converts this snapshot to a format which it then signs.

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
 chains.tekton.dev/cert-taskrun-f96d34f5-b711-4378-8200-9c0b67265922=
 chains.tekton.dev/chain-taskrun-f96d34f5-b711-4378-8200-9c0b67265922=
 chains.tekton.dev/payload-taskrun-f96d34f5-b711-4378-8200-9c0b67265922=eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOlt7Im5hbWUiOiJnY3IuaW8vZm9vL2JhciIsImRpZ2VzdCI6eyJzaGEyNTYiOiIwNWY5NWIyNmVkMTA2NjhiNzE4M2MxZTJkYTk4NjEwZTkxMzcyZmE5ZjUxMDA0NmQ0Y2U1ODEyYWRkYWQ4NmI1In19XSwicHJlZGljYXRlIjp7ImJ1aWxkZXIiOnsiaWQiOiJodHRwczovL3Rla3Rvbi5kZXYvY2hhaW5zL3YyIn0sImJ1aWxkVHlwZSI6InRla3Rvbi5kZXYvdjFiZXRhMS9UYXNrUnVuIiwiaW52b2NhdGlvbiI6eyJjb25maWdTb3VyY2UiOnt9LCJwYXJhbWV0ZXJzIjp7fX0sImJ1aWxkQ29uZmlnIjp7InN0ZXBzIjpbeyJlbnRyeVBvaW50IjoiIyEvdXNyL2Jpbi9lbnYgc2hcbmVjaG8gJ2djci5pby9mb28vYmFyJyB8IHRlZSAvdGVrdG9uL3Jlc3VsdHMvSU1BR0VfVVJMXG5lY2hvICdzaGEyNTY6MDVmOTViMjZlZDEwNjY4YjcxODNjMWUyZGE5ODYxMGU5MTM3MmZhOWY1MTAwNDZkNGNlNTgxMmFkZGFkODZiNScgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL0lNQUdFX0RJR0VTVCIsImFyZ3VtZW50cyI6bnVsbCwiZW52aXJvbm1lbnQiOnsiY29udGFpbmVyIjoiY3JlYXRlLWltYWdlIiwiaW1hZ2UiOiJkb2NrZXIuaW8vbGlicmFyeS9idXN5Ym94QHNoYTI1NjpjMTE4ZjUzODM2NTM2OTIwN2MxMmU1Nzk0YzNjYmZiN2IwNDJkOTUwYWY1OTBhZTZjMjg3ZWRlNzRmMjliN2Q0In0sImFubm90YXRpb25zIjpudWxsfV19LCJtZXRhZGF0YSI6eyJidWlsZFN0YXJ0ZWRPbiI6IjIwMjMtMDMtMTFUMDk6NDQ6NDVaIiwiYnVpbGRGaW5pc2hlZE9uIjoiMjAyMy0wMy0xMVQwOTo0NDo1MFoiLCJjb21wbGV0ZW5lc3MiOnsicGFyYW1ldGVycyI6ZmFsc2UsImVudmlyb25tZW50IjpmYWxzZSwibWF0ZXJpYWxzIjpmYWxzZX0sInJlcHJvZHVjaWJsZSI6ZmFsc2V9fX0=
 chains.tekton.dev/signature-taskrun-f96d34f5-b711-4378-8200-9c0b67265922=eyJwYXlsb2FkVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5pbi10b3RvK2pzb24iLCJwYXlsb2FkIjoiZXlKZmRIbHdaU0k2SW1oMGRIQnpPaTh2YVc0dGRHOTBieTVwYnk5VGRHRjBaVzFsYm5RdmRqQXVNU0lzSW5CeVpXUnBZMkYwWlZSNWNHVWlPaUpvZEhSd2N6b3ZMM05zYzJFdVpHVjJMM0J5YjNabGJtRnVZMlV2ZGpBdU1pSXNJbk4xWW1wbFkzUWlPbHQ3SW01aGJXVWlPaUpuWTNJdWFXOHZabTl2TDJKaGNpSXNJbVJwWjJWemRDSTZleUp6YUdFeU5UWWlPaUl3TldZNU5XSXlObVZrTVRBMk5qaGlOekU0TTJNeFpUSmtZVGs0TmpFd1pUa3hNemN5Wm1FNVpqVXhNREEwTm1RMFkyVTFPREV5WVdSa1lXUTRObUkxSW4xOVhTd2ljSEpsWkdsallYUmxJanA3SW1KMWFXeGtaWElpT25zaWFXUWlPaUpvZEhSd2N6b3ZMM1JsYTNSdmJpNWtaWFl2WTJoaGFXNXpMM1l5SW4wc0ltSjFhV3hrVkhsd1pTSTZJblJsYTNSdmJpNWtaWFl2ZGpGaVpYUmhNUzlVWVhOclVuVnVJaXdpYVc1MmIyTmhkR2x2YmlJNmV5SmpiMjVtYVdkVGIzVnlZMlVpT250OUxDSndZWEpoYldWMFpYSnpJanA3Zlgwc0ltSjFhV3hrUTI5dVptbG5JanA3SW5OMFpYQnpJanBiZXlKbGJuUnllVkJ2YVc1MElqb2lJeUV2ZFhOeUwySnBiaTlsYm5ZZ2MyaGNibVZqYUc4Z0oyZGpjaTVwYnk5bWIyOHZZbUZ5SnlCOElIUmxaU0F2ZEdWcmRHOXVMM0psYzNWc2RITXZTVTFCUjBWZlZWSk1YRzVsWTJodklDZHphR0V5TlRZNk1EVm1PVFZpTWpabFpERXdOalk0WWpjeE9ETmpNV1V5WkdFNU9EWXhNR1U1TVRNM01tWmhPV1kxTVRBd05EWmtOR05sTlRneE1tRmtaR0ZrT0RaaU5TY2dmQ0IwWldVZ0wzUmxhM1J2Ymk5eVpYTjFiSFJ6TDBsTlFVZEZYMFJKUjBWVFZDSXNJbUZ5WjNWdFpXNTBjeUk2Ym5Wc2JDd2laVzUyYVhKdmJtMWxiblFpT25zaVkyOXVkR0ZwYm1WeUlqb2lZM0psWVhSbExXbHRZV2RsSWl3aWFXMWhaMlVpT2lKa2IyTnJaWEl1YVc4dmJHbGljbUZ5ZVM5aWRYTjVZbTk0UUhOb1lUSTFOanBqTVRFNFpqVXpPRE0yTlRNMk9USXdOMk14TW1VMU56azBZek5qWW1aaU4ySXdOREprT1RVd1lXWTFPVEJoWlRaak1qZzNaV1JsTnpSbU1qbGlOMlEwSW4wc0ltRnVibTkwWVhScGIyNXpJanB1ZFd4c2ZWMTlMQ0p0WlhSaFpHRjBZU0k2ZXlKaWRXbHNaRk4wWVhKMFpXUlBiaUk2SWpJd01qTXRNRE10TVRGVU1EazZORFE2TkRWYUlpd2lZblZwYkdSR2FXNXBjMmhsWkU5dUlqb2lNakF5TXkwd015MHhNVlF3T1RvME5EbzFNRm9pTENKamIyMXdiR1YwWlc1bGMzTWlPbnNpY0dGeVlXMWxkR1Z5Y3lJNlptRnNjMlVzSW1WdWRtbHliMjV0Wlc1MElqcG1ZV3h6WlN3aWJXRjBaWEpwWVd4eklqcG1ZV3h6Wlgwc0luSmxjSEp2WkhWamFXSnNaU0k2Wm1Gc2MyVjlmWDA9Iiwic2lnbmF0dXJlcyI6W3sia2V5aWQiOiJTSEEyNTY6Y2FFSldZSlN4eTFTVkYyS09ibTVScjNZdDZ4SWI0VDJ3NTZGSHRDZzhXSSIsInNpZyI6Ik1FVUNJR3U2U01iZVJ6VEdaMXVJWGhrOUFMK2F4Zmh5VkZWUUVycWZEaXlzaVgrU0FpRUEvT2FDVHd0TVhmUUFKVk9uSm4xVkdVVHU5RTlLNHVaYURXTlpmTThzTmEwPSJ9XX0=
 chains.tekton.dev/signed=true
 pipeline.tekton.dev/release=e38d112

🌡️  Status

STARTED         DURATION    STATUS
7 minutes ago   5s          Succeeded

📝 Results

 NAME             VALUE
 ∙ IMAGE_DIGEST   sha256:05f95b26ed10668b7183c1e2da98610e91372fa9f510046d4ce5812addad86b5
 ∙ IMAGE_URL      gcr.io/foo/bar

🦶 Steps

 NAME             STATUS
 ∙ create-image   Completed
```
Notice that the task has an IMAGE_DIGEST result which I'm guessing at the moment
is used by the chain controller.
Also notice the
`chains.tekton.dev/signature-taskrun-f96d34f5-b711-4378-8200-9c0b67265922`
annotation which contains a base64 encoded value. So lets decode this and
see what it contains:
```console
$ make chain-attestation-base64-decode
{
  "payloadType": "application/vnd.in-toto+json",
  "payload": "eyJfdHlwZSI6Imh0dHBzOi8vaW4tdG90by5pby9TdGF0ZW1lbnQvdjAuMSIsInByZWRpY2F0ZVR5cGUiOiJodHRwczovL3Nsc2EuZGV2L3Byb3ZlbmFuY2UvdjAuMiIsInN1YmplY3QiOlt7Im5hbWUiOiJnY3IuaW8vZm9vL2JhciIsImRpZ2VzdCI6eyJzaGEyNTYiOiIwNWY5NWIyNmVkMTA2NjhiNzE4M2MxZTJkYTk4NjEwZTkxMzcyZmE5ZjUxMDA0NmQ0Y2U1ODEyYWRkYWQ4NmI1In19XSwicHJlZGljYXRlIjp7ImJ1aWxkZXIiOnsiaWQiOiJodHRwczovL3Rla3Rvbi5kZXYvY2hhaW5zL3YyIn0sImJ1aWxkVHlwZSI6InRla3Rvbi5kZXYvdjFiZXRhMS9UYXNrUnVuIiwiaW52b2NhdGlvbiI6eyJjb25maWdTb3VyY2UiOnt9LCJwYXJhbWV0ZXJzIjp7fX0sImJ1aWxkQ29uZmlnIjp7InN0ZXBzIjpbeyJlbnRyeVBvaW50IjoiIyEvdXNyL2Jpbi9lbnYgc2hcbmVjaG8gJ2djci5pby9mb28vYmFyJyB8IHRlZSAvdGVrdG9uL3Jlc3VsdHMvSU1BR0VfVVJMXG5lY2hvICdzaGEyNTY6MDVmOTViMjZlZDEwNjY4YjcxODNjMWUyZGE5ODYxMGU5MTM3MmZhOWY1MTAwNDZkNGNlNTgxMmFkZGFkODZiNScgfCB0ZWUgL3Rla3Rvbi9yZXN1bHRzL0lNQUdFX0RJR0VTVCIsImFyZ3VtZW50cyI6bnVsbCwiZW52aXJvbm1lbnQiOnsiY29udGFpbmVyIjoiY3JlYXRlLWltYWdlIiwiaW1hZ2UiOiJkb2NrZXIuaW8vbGlicmFyeS9idXN5Ym94QHNoYTI1NjpjMTE4ZjUzODM2NTM2OTIwN2MxMmU1Nzk0YzNjYmZiN2IwNDJkOTUwYWY1OTBhZTZjMjg3ZWRlNzRmMjliN2Q0In0sImFubm90YXRpb25zIjpudWxsfV19LCJtZXRhZGF0YSI6eyJidWlsZFN0YXJ0ZWRPbiI6IjIwMjMtMDMtMTFUMDk6NDQ6NDVaIiwiYnVpbGRGaW5pc2hlZE9uIjoiMjAyMy0wMy0xMVQwOTo0NDo1MFoiLCJjb21wbGV0ZW5lc3MiOnsicGFyYW1ldGVycyI6ZmFsc2UsImVudmlyb25tZW50IjpmYWxzZSwibWF0ZXJpYWxzIjpmYWxzZX0sInJlcHJvZHVjaWJsZSI6ZmFsc2V9fX0=",
  "signatures": [
    {
      "keyid": "SHA256:caEJWYJSxy1SVF2KObm5Rr3Yt6xIb4T2w56FHtCg8WI",
      "sig": "MEUCIGu6SMbeRzTGZ1uIXhk9AL+axfhyVFVQErqfDiysiX+SAiEA/OaCTwtMXfQAJVOnJn1VGUTu9E9K4uZaDWNZfM8sNa0="
    }
  ]
}
```
Now this looks familiar. What we have is an [in-toto attestation].
Lets inspect the `payload`:
```console
$ make show-attestation-payload
tkn tr describe --last -o jsonpath="{.metadata.annotations.chains\.tekton\.dev/signature-taskrun-f96d34f5-b711-4378-8200-9c0b67265922}"  | base64 -d | jq -r '.payload' | base64 -d | jq
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": [
    {
      "name": "gcr.io/foo/bar",
      "digest": {
        "sha256": "05f95b26ed10668b7183c1e2da98610e91372fa9f510046d4ce5812addad86b5"
      }
    }
  ],
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
          "entryPoint": "#!/usr/bin/env sh\necho 'gcr.io/foo/bar' | tee /tekton/results/IMAGE_URL\necho 'sha256:05f95b26ed10668b7183c1e2da98610e91372fa9f510046d4ce5812addad86b5' | tee /tekton/results/IMAGE_DIGEST",
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
      "buildStartedOn": "2023-03-11T09:44:45Z",
      "buildFinishedOn": "2023-03-11T09:44:50Z",
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
And from this we can see that the payload contains a SLSA Provenance predicate.

And we can verify using:
```console
$ make verify-signature 
cosign verify-blob -d --key k8s://tekton-chains/signing-secrets --signature attestation attestation
Verified OK
```

[in-toto attestation]: https://github.com/danbev/learning-crypto/blob/main/notes/in-toto-attestations.md#in-toto-attestation
