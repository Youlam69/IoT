# Inception-of-Things (IoT)

42 system-administration project: a hands-on introduction to Kubernetes through
**Vagrant**, **K3s**, **K3d** and **Argo CD**.

| Part | What it builds | Run it with |
| --- | --- | --- |
| [`p1`](p1) | Two Vagrant VMs, K3s controller + agent | `cd p1 && vagrant up` |
| [`p2`](p2) | One VM, K3s server, three apps behind a Host-routed Ingress | `cd p2 && vagrant up` |
| [`p3`](p3) | K3d + Argo CD, deploying from GitHub | `./p3/scripts/install.sh && ./p3/scripts/setup.sh` |
| [`bonus`](bonus) | The same, sourced from a **locally hosted GitLab** | `./bonus/scripts/setup.sh` |

Login used throughout: **`aelyakou`**.

## Layout

```
.
├── p1/                     Part 1 — K3s and Vagrant
│   ├── Vagrantfile
│   ├── confs/
│   └── scripts/            server.sh, worker.sh
├── p2/                     Part 2 — K3s and three simple applications
│   ├── Vagrantfile
│   ├── confs/              app-one/two/three.yaml, ingress.yaml
│   └── scripts/            server.sh, deploy.sh
├── p3/                     Part 3 — K3d and Argo CD
│   ├── confs/              k3d-cluster, namespaces, argocd Application
│   ├── scripts/            install.sh, setup.sh, port-forward.sh, …
│   └── app-repo/           manifests to push to the public GitHub repo
└── bonus/                  Bonus — GitLab
    ├── Vagrantfile
    ├── confs/              k3d-cluster, gitlab values, Application
    └── scripts/            setup.sh, credentials.sh, teardown.sh
```

## Requirements

- **Parts 1 & 2**: Vagrant ≥ 2.3 and VirtualBox on the host machine.
- **Part 3 & bonus**: run inside a Linux VM. `p3/scripts/install.sh` installs
  everything else (Docker, kubectl, k3d, helm, the Argo CD CLI).

Each part has its own README with the full walkthrough and the commands to show
during the defense.

## Addresses

| | |
| --- | --- |
| `p1` server / `p2` server | `192.168.56.110` |
| `p1` worker | `192.168.56.111` |
| `bonus` VM | `192.168.56.120` |
| Argo CD UI (p3) | `https://localhost:8080` |
| Application (p3) | `http://localhost:8888` |
| GitLab (bonus) | `http://gitlab.gitlab.local` |
