# Part 3 — K3d and Argo CD

No Vagrant here: everything runs on your own VM, inside Docker, via K3d.
Argo CD then deploys an app from a public GitHub repo into the `dev` namespace.

```
GitHub                 ┌──── k3d cluster "iot" ────┐
aelyakou-iot  ───────▶ │  argocd ──▶ dev           │
(deployment.yaml)      │  Argo CD    wil-playground│
                       └───────────────────────────┘
```

**K3s vs K3d**: K3s is a lightweight Kubernetes you install on a machine —
that is what Parts 1 and 2 do. K3d runs that same K3s inside **Docker
containers**, one container per node, so a cluster starts in seconds and is
deleted just as fast. K3d needs Docker; K3s does not.

## Run

```sh
./p3/scripts/install.sh    # docker, kubectl, k3d, helm, argocd (uses sudo)
newgrp docker              # so docker works without sudo
./p3/scripts/setup.sh      # cluster + namespaces + Argo CD + the app
```

## Check

```sh
kubectl get ns             # argocd, dev
kubectl get pods -n dev    # wil-playground-...  1/1  Running
curl http://localhost:8888/
# {"status":"ok", "message": "v1"}
```

Both are reachable directly, with no port-forward: `confs/k3d-cluster.yaml`
publishes host ports 8080 and 8888 on k3d's load balancer, which proxies them
to NodePort 30080 (`argocd-server`) and NodePort 30888 (`wil-playground`).

Argo CD UI: <https://localhost:8080>, user `admin`, password from
`./p3/scripts/credentials.sh`. The certificate is self-signed, so accept
the browser warning.

## The v1 → v2 demo

The manifests Argo CD watches live in a **separate public repo**,
<https://github.com/EldritchGriffin/aelyakou-iot> — its name contains the login, as
the subject requires. The files to push there are in
[`app-repo/`](app-repo); see [`app-repo/README.md`](app-repo/README.md).

In that repo:

```sh
sed -i 's|playground:v1|playground:v2|' deployment.yaml
git commit -am "v2" && git push
```

or just `./switch-version.sh`. Then watch it land:

```sh
kubectl -n dev get pods -w
curl http://localhost:8888/
# {"status":"ok", "message": "v2"}
```

Argo CD is set to check git every 30s instead of the default 3 minutes.
`argocd app sync wil-playground` forces it immediately.

## Files

| File | Role |
| --- | --- |
| `scripts/install.sh` | Installs every tool. Safe to re-run. |
| `scripts/setup.sh` | Builds the whole cluster. |
| `scripts/credentials.sh` | Prints the Argo CD password. |
| `scripts/teardown.sh` | Deletes the cluster. |
| `confs/k3d-cluster.yaml` | The k3d cluster, and the two published host ports. |
| `confs/namespaces.yaml` | The `argocd` and `dev` namespaces. |
| `confs/application.yaml` | Which repo Argo CD watches and where it deploys. |
| `confs/argocd-cm-patch.yaml` | The 30s sync interval. |

## Clean up

```sh
./p3/scripts/teardown.sh
```
