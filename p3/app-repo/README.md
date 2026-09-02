# aelyakou-iot — the repo Argo CD watches

**These files are not deployed from here.** They belong in a **separate public
GitHub repository**, because `p3/confs/application.yaml` points at:

```
repoURL: https://github.com/EldritchGriffin/aelyakou-iot
path:    .
```

The subject requires that repo's name to contain a group member's login —
hence `aelyakou-iot`.

## One-time setup

Create the public repo on GitHub, then push these files to its root:

```sh
cd p3/app-repo
git init -b main
git add deployment.yaml service.yaml
git commit -m "playground v1"
git remote add origin git@github.com:EldritchGriffin/aelyakou-iot.git
git push -u origin main
```

Because `path: .`, Argo CD applies every manifest at the repo root.

## Switching version

```sh
sed -i 's|playground:v1|playground:v2|' deployment.yaml
git commit -am "v2" && git push
```

## Files

| File | Role |
| --- | --- |
| `deployment.yaml` | `eldergriffi/playground` on port 8888. The image tag is what you change. |
| `service.yaml` | NodePort 30888, published by k3d as `http://localhost:8888`. |
