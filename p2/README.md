# Part 2 — K3s and three simple applications

One machine (`aelyakouS`, `192.168.56.110`) running K3s, with three apps
routed by the HTTP `Host` header through Traefik.

| `Host:` header | Application | Replicas |
| --- | --- | --- |
| `app1.com` | `app-one` | 1 |
| `app2.com` | `app-two` | **3** |
| anything else | `app-three` | 1 |

## Run

```sh
cd p2
vagrant up
```

## Check

From your host, no `/etc/hosts` edit needed:

```sh
curl -s -H "Host: app1.com" http://192.168.56.110/ | grep h1
curl -s -H "Host: app2.com" http://192.168.56.110/ | grep h1
curl -s -H "Host: whatever" http://192.168.56.110/ | grep h1
```

For a browser, add this to your host's `/etc/hosts`:

```
192.168.56.110 app1.com app2.com
```

Each page prints the pod that served it, so app-two's three replicas are
visible by repeating the request:

```sh
for i in 1 2 3 4 5; do curl -s -H "Host: app2.com" http://192.168.56.110/ | grep Pod; done
```

Show the Ingress to the evaluators — the subject asks for it explicitly:

```sh
vagrant ssh -c "kubectl get ingress"
vagrant ssh -c "kubectl describe ingress apps-ingress"
```

## Files

| File | Role |
| --- | --- |
| `scripts/server.sh` | Installs K3s and waits for Traefik. |
| `scripts/deploy.sh` | Applies `confs/`, waits for the rollouts, prints the routes. |
| `confs/apps.yaml` | The three `Deployment`s and their `Service`s. |
| `confs/ingress.yaml` | The Host-based routing rules. |

Each app is plain `nginx:alpine` that writes a small HTML page on start-up.
The page includes `$(hostname)` — inside a pod that is the pod's name, which
is what makes the replicas visible.

The default route is an Ingress rule with **no host**, so it matches anything.
Traefik ranks rules by specificity, so `app1.com` and `app2.com` match first
and everything else falls through to `app-three`.

## Clean up

```sh
vagrant destroy -f
```
