# Part 3 — K3d and Argo CD

No Vagrant here: everything runs on your own VM, inside Docker, via K3d.
Argo CD then deploys an app from a public GitHub repo into the `dev` namespace.

```
GitHub                      ┌──── k3d cluster "iot" ────────┐
aelyakou-iot  ────────────▶ │  argocd ──▶ dev               │
(deployment.yaml)           │  Argo CD    aelyakou-playground│
                            └───────────────────────────────┘
```

**K3s vs K3d**: K3s is a lightweight Kubernetes you install on a machine —
that is what Parts 1 and 2 do. K3d runs that same K3s inside **Docker
containers**, one container per node, so a cluster starts in seconds and is
deleted just as fast. K3d needs Docker; K3s does not.

## Run

```sh
./p3/scripts/install.sh    # docker, kubectl, k3d (uses sudo)
newgrp docker              # so docker works without sudo
./p3/scripts/setup.sh      # cluster + namespaces + Argo CD + the app
```

## Check

```sh
kubectl get ns              # argocd, dev
kubectl get pods -n dev     # aelyakou-playground-...  1/1  Running
curl http://localhost:8888/
# {"status":"ok", "message": "v1"}
```

No port-forward is needed. `setup.sh` creates the cluster with
`-p 8080:30080@loadbalancer -p 8888:30888@loadbalancer`, and both services are
`NodePort`: 30080 for `argocd-server`, 30888 for the application.

Argo CD UI: <https://localhost:8080>, user `admin`, password from
`./p3/scripts/credentials.sh`. The certificate is self-signed, so accept
the browser warning.

## The v1 → v2 demo

The manifests Argo CD watches live in a **separate public repo**,
<https://github.com/EldritchGriffin/aelyakou-iot> — its name contains the login,
as the subject requires. The files to push there are in
[`app-repo/`](app-repo); see [`app-repo/README.md`](app-repo/README.md).

In that repo:

```sh
sed -i 's|playground:v1|playground:v2|' deployment.yaml
git commit -am "v2" && git push
```

Then watch it land — Argo CD checks git every 30s instead of the default
3 minutes, or press SYNC in the UI:

```sh
kubectl -n dev get pods -w
curl http://localhost:8888/
# {"status":"ok", "message": "v2"}
```

## Files

| File | Role |
| --- | --- |
| `scripts/install.sh` | Installs docker, kubectl and k3d. Safe to re-run. |
| `scripts/setup.sh` | Builds the whole cluster. |
| `scripts/credentials.sh` | Prints the Argo CD password. |
| `scripts/teardown.sh` | Deletes the cluster. |
| `confs/namespaces.yaml` | The `argocd` and `dev` namespaces. |
| `confs/application.yaml` | Which repo Argo CD watches and where it deploys. |
| `app/` | The application: `main.go`, `Dockerfile`, `build.sh`. |
| `app-repo/` | The manifests that belong in the public GitHub repo. |

## The application

`app/` builds `eldergriffi/playground`, a ~20-line Go server answering
`{"status":"ok", "message": "vN"}` on port 8888. The subject allows using your
own app instead of `wil42/playground`, which is amd64-only; this one is built
for **amd64 and arm64**, so it runs on Apple Silicon too.

```sh
docker login
./p3/app/build.sh          # cross-compiles and pushes :v1 and :v2
```

## Clean up

```sh
./p3/scripts/teardown.sh
```
