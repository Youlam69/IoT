# Bonus — GitLab

Part 3, with the git repo moved **inside the cluster**: GitLab installed from
the official Helm chart into its own `gitlab` namespace, with Argo CD
deploying from it instead of from GitHub.

```
┌──────────── k3d cluster "iot" ────────────┐
│  gitlab ──▶ argocd ──▶ dev                │
│  (Helm)     Argo CD    wil-playground     │
└───────────────────────────────────────────┘
```

> The bonus is only evaluated if the mandatory part is flawless.

## Run

GitLab needs **8 GB of RAM and 4 CPUs**, and 10–20 minutes to start.

If your VM already has that headroom:

```sh
./p3/scripts/install.sh
./bonus/scripts/setup.sh
```

If it does not, use the bigger machine defined here (`aelyakouB`,
`192.168.56.120`):

```sh
cd bonus
vagrant up
vagrant ssh
/iot/bonus/scripts/setup.sh
```

`setup.sh` installs Helm, creates the cluster (this one publishes ports 80 and
443 so the GitLab Ingress is reachable), the three namespaces, GitLab and Argo CD, then
prints both passwords and the three manual steps left: create a **public**
project `aelyakou-iot` under `root`, push `p3/app-repo/`'s manifests to it,
and `kubectl apply -f bonus/confs/application.yaml`.

## Check

```sh
kubectl get ns                  # argocd, dev, gitlab
kubectl -n gitlab get pods
./bonus/scripts/credentials.sh
```

GitLab: <http://gitlab.gitlab.local>, user `root`.

Then run the same v1 → v2 demo as Part 3, pushing to GitLab instead:

```sh
sed -i 's|playground:v1|playground:v2|' deployment.yaml
git commit -am "v2" && git push gitlab main
kubectl -n dev get pods -w
curl http://localhost:8888/
```

## Files

| File | Role |
| --- | --- |
| `confs/gitlab-values.yaml` | Helm values, trimmed for a single node. |
| `confs/application.yaml` | Argo CD reading from GitLab's in-cluster Service. |

## Clean up

```sh
./bonus/scripts/teardown.sh
```
