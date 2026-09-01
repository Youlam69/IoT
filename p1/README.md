# Part 1 — K3s and Vagrant

Two machines forming one K3s cluster.

| Machine | Hostname | IP | Role |
| --- | --- | --- | --- |
| Server | `aelyakouS` | `192.168.56.110` | K3s **controller** |
| ServerWorker | `aelyakouSW` | `192.168.56.111` | K3s **agent** |

Each VM gets 1 CPU and 1024 MB of RAM.

## Run

```sh
cd p1
vagrant up
```

The server starts first and writes its token into the `shared/` folder; the
worker waits for that token, then joins `https://192.168.56.110:6443`.

## Check

```sh
vagrant ssh aelyakouS -c "kubectl get nodes -o wide"
```

```
NAME         STATUS   ROLES                  AGE   VERSION        INTERNAL-IP
aelyakous    Ready    control-plane,master   3m    v1.3x.x+k3s1   192.168.56.110
aelyakousw   Ready    <none>                 1m    v1.3x.x+k3s1   192.168.56.111
```

SSH needs no password on either machine — Vagrant installs a key for each:

```sh
vagrant ssh aelyakouS
vagrant ssh aelyakouSW
```

## Files

| File | Role |
| --- | --- |
| `Vagrantfile` | The two machines. Provisioning is delegated to `scripts/`. |
| `scripts/server.sh` | Installs K3s in server mode and shares the node token. |
| `scripts/worker.sh` | Waits for the token, then installs K3s in agent mode. |

Two things worth explaining at the defense:

- **K3s is pinned to the private network.** `--node-ip` and
  `--flannel-iface=eth1` keep the cluster off `eth0`, the NAT interface
  Vagrant uses for SSH. `eth1` is the private interface on
  `bento/ubuntu-24.04`; on a box that uses predictable names it would be
  `enp0s8`, so check with `ip a` if you change the box.
- **kubectl is installed separately.** K3s embeds its own, but the subject
  asks for kubectl, so the scripts download it to `/usr/local/bin`.

## Clean up

```sh
vagrant destroy -f
```
