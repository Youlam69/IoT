# aelyakou-iot — the repo Argo CD watches

**These files are not deployed from here.** They belong in a **separate public
GitHub repository**, because `p3/confs/application.yaml` points at:

```
repoURL: https://github.com/Youlam69/aelyakou-iot.git
path:    .
```

The subject requires that repo's name to contain a group member's login —
hence `aelyakou-iot`.

## One-time setup

Create the public repo on GitHub, then push these files to its root:

```sh
cd p3/app-repo
git init -b main
git add deployment.yaml service.yaml switch-version.sh README.md
git commit -m "playground v1"
git remote add origin git@github.com:Youlam69/aelyakou-iot.git
git push -u origin main
```

Because `path: .`, Argo CD applies every manifest at the repo root.

## Files

| File | Role |
| --- | --- |
| `deployment.yaml` | `wil42/playground` on port 8888. The image tag is what you change. |
| `service.yaml` | ClusterIP service on 8888, the port-forward target. |
| `switch-version.sh` | Toggles the tag between `v1` and `v2`, commits and pushes. |
