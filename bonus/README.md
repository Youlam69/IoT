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

GitLab needs **8 GB of RAM and 4 CPUs**, and 10–20 minutes to start. The chart
is pinned to **9.11.12** (GitLab 18.11.11): chart 10.x dropped the bundled
PostgreSQL, Redis and object storage and requires them as external services.

Like Part 3, this runs directly on your VM - no Vagrant:

```sh
./p3/scripts/install.sh
./bonus/scripts/setup.sh
```

`setup.sh` does the whole thing: installs Helm, creates the cluster (this one
also publishes port 80 so the GitLab Ingress is reachable), the namespaces,
GitLab and Argo CD. It then logs into GitLab's API with the root password,
creates the **public** project `aelyakou-iot`, pushes `p3/app-repo/`'s
manifests to it, and applies `bonus/confs/application.yaml` so Argo CD deploys
from GitLab. Nothing is left to do by hand.

If the API step fails it says so and prints the manual equivalent.

## Check

```sh
kubectl get ns                  # argocd, dev, gitlab
kubectl -n gitlab get pods
./bonus/scripts/credentials.sh
```

GitLab: <http://gitlab.gitlab.local>, user `root`.

Then run the same v1 → v2 demo as Part 3, against GitLab instead of GitHub:

```sh
git clone http://gitlab.gitlab.local/root/aelyakou-iot.git && cd aelyakou-iot
sed -i 's|playground:v1|playground:v2|' deployment.yaml
git commit -am "v2" && git push
kubectl -n dev get pods -w
curl http://localhost:8888/
```

## Files

| File | Role |
| --- | --- |
| `confs/gitlab-values.yaml` | Helm values, trimmed for a single node. |
| `confs/application.yaml` | Argo CD reading from GitLab's in-cluster Service. |

## Clean up

It is the same cluster Part 3 uses, so Part 3's teardown removes GitLab with it:

```sh
./p3/scripts/teardown.sh
sudo sed -i '/# iot-bonus/d' /etc/hosts
```
