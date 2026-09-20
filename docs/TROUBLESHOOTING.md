# Troubleshooting log and runbook

Everything that went wrong while building the GitOps setup (Argo CD, App-of-Apps, PR previews, External Secrets), with the cause and the fix. The runbook at the end lists the steps in the order they were done.

## Errors, causes and fixes

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `./scripts/10-minikube-build.sh: No such file or directory`, then `namespaces "argocd" not found`, `"vaultai-dev" not found`, `"vaultai-pr-dev" not found` | The bundle zip was never unzipped into the repo, so the scripts did not exist. Argo CD was never installed, so its namespaces did not exist either. Every later error came from this one. | `cp` the zip into `~/`, then `unzip -o` it inside `~/vaultai`, check `ls scripts/`, then run `./scripts/30-all-in-one.sh`. |
| 2 | `command not found` for lines like `Forwarding: command not found` and `vishal@Joyboy:~$: No such file` | Terminal output, including the prompt, was pasted back into the shell. | Paste only the commands, never the output or the `user@host:~$` prompt. |
| 3 | Browser: `ERR_CONNECTION_REFUSED` on `localhost:8080` or `9000` | `kubectl port-forward` is a foreground process. Ctrl+C, `pkill -f port-forward`, closing the terminal or restarting WSL kills it. | Restart it in the background: `setsid nohup ./scripts/22-argocd-ui.sh > /tmp/argocd-ui.log 2>&1 &`. Verify with `ss -ltn \| grep 8080`. A `curl` run 3 seconds after starting can print `000` because the port is not ready yet, so wait and retry. |
| 4 | `Unable to listen on port 9001: address already in use` | An earlier manual `port-forward ... &` was still running in the background. | `ss -ltn \| grep 9001` to confirm, `pkill -f port-forward` to clear. The preview script takes the port as its second argument: `./scripts/26-preview-open.sh <pr> <port>`. |
| 5 | Argo CD "self-heal" test showed pods in `Error` after scaling to 3 | Extra pods were terminated seconds after starting, before finishing boot. This is expected. | No fix needed. The original pod stayed `Running`, so there was no downtime. |
| 6 | `curl https://charts.external-secrets.io/index.yaml \| grep -c "version: 2.6.0"` printed `0` although the chart exists | The chart host redirects to `external-secrets.io`, and `curl` without `-L` does not follow redirects. | Use `curl -sL`. |
| 7 | New Argo CD Application showed blank sync and health right after creation | It had not been reconciled yet. | Wait 1-3 minutes, or run `kubectl -n argocd annotate application root argocd.argoproj.io/refresh=hard --overwrite`. |
| 8 | ESO smoke test: `SecretSyncedError`, and the target secret was not found | The source secret `vaultai-db-source` had not been created in `vault-source`. | Create it with `kubectl -n vault-source create secret generic vaultai-db-source --from-literal=POSTGRES_PASSWORD=...` (copied from the existing dev secret, never printed). Do this before switching the chart to the ExternalSecret. |
| 9 | `manual-sync-demo` namespace still `Active` after deleting the Application | Namespaces created through `CreateNamespace=true` are not deleted with the Application. | `kubectl delete ns manual-sync-demo`. |
| 10 | `vaultai-dev` stuck at `Progressing` for over 2 hours; postgres pod `0/1 Running` and flipping between Ready and NotReady | The readiness probe (`pg_isready`) had no `timeoutSeconds`, so Kubernetes used the 1 second default. Postgres was also limited to 250m CPU, and the minikube node was under load. `describe pod` showed `Readiness probe failed: command timed out ... after 1s`. Postgres itself was healthy and had started on the new password. | In `charts/vaultai-preview/templates/postgres.yaml`: add `timeoutSeconds: 5` and `failureThreshold: 6` to the readiness probe, and raise the CPU limit to 500m. After the fix all four pods were `1/1 Running` and the app was `Synced` / `Healthy`. |
| 11 | `context deadline exceeded` readiness failures on api, frontend and gateway at the same moment | Same root cause: the node was overloaded during the deploy, and their probes also use the 1 second default. They recovered by themselves. | If it recurs, add `timeoutSeconds: 5` to those probes too, close any open preview PR, or give minikube more memory. |
| 12 | Preview pods in `ImagePullBackOff` or `ErrImageNeverPull` | Images are tagged with the PR head commit and exist only inside minikube. If the PR is opened or updated before the images for that exact commit are built, the tag is missing. Reopening an old PR (for example #1) fails the same way, because nothing was built for its commit. | Order is always: commit, run `./scripts/11-build-branch.sh`, push, then open or update the PR. Check with `minikube image ls \| grep $(git rev-parse --short=8 HEAD)`. |
| 13 | `kubectl top pods` says `Metrics not available for pod ...` right after `minikube addons enable metrics-server` | metrics-server needs one or two scrape cycles before it has data. | Wait 2-3 minutes and retry. Check `kubectl -n kube-system get pods \| grep metrics-server` is `1/1 Running`. |
| 14 | `kubectl get pods -A -l vaultai.dev/pr=2` returned `No resources found` although the Deployments had the label | The environment labels were only on the Deployments, not on the pod template. Logs and metrics select pods. | Add a `vp.podLabels` helper (PR number and part-of, no commit label) and include it under `spec.template.metadata.labels` in all four Deployments. The commit label is left out on purpose: it changes on every push, and a changed pod template restarts every pod, including Postgres. |
| 15 | A chart fix pushed to `main` did not appear in an open preview | A preview reads its chart from the PR's own commit (`targetRevision: head_sha`), not from `main`. | Merge `main` into the PR branch, rebuild the images for the new head commit with `11-build-branch.sh`, then push. |
| 16 | Image tag parameter could be mangled | A short commit SHA can be all digits or look like scientific notation (for example `1e567890`), and Helm would read it as a number. | `forceString: true` on both `images.*.tag` parameters in the ApplicationSet. |
| 17 | `helm: command not found` when validating the chart locally | Helm is not installed in WSL. | Not required, because Argo CD renders the chart itself and reports render errors on the Application. Optional: `sudo snap install helm`. |
| 18 | `Executing "docker container inspect minikube" took an unusually long time` during builds | The machine is under load (4.8 GB RAM shared by minikube, Argo CD, ESO and the previews). | Harmless on its own, but it is the same pressure that made the Postgres probe flap. Keep only one preview open and disable metrics-server when not needed (`minikube addons disable metrics-server`). |

### Harmless messages
- `Warning: metadata.finalizers: "resources-finalizer.argocd.argoproj.io": prefer a domain-qualified finalizer name` is only a style warning.
- `Broken pipe` / `connection to client lost` in Postgres logs is clients disconnecting.
- The Jenkins check on a PR stays pending. It comes from the older Jenkins pipeline and is unrelated to Argo CD.

### Things to remember
- Git asks for a username and password on every push. The password is a GitHub personal access token, not the account password.
- Keep at most one preview PR open. Each preview is a full copy of the app, and the node has about 4.8 GB of RAM.
- Build before you push: commit, `./scripts/11-build-branch.sh`, push, then open or update the PR. A preview can only start if the images for its commit are already inside minikube.
- Do not rotate the real database password to demo rotation. Postgres only reads `POSTGRES_PASSWORD` when it first initializes its data directory, so changing the secret later would lock the API out. Use a throwaway secret.
- "dev" here means the always-on development environment (`vaultai-dev`, tracking `main`). Its database uses an `emptyDir`, so data is lost when Postgres restarts. That is acceptable for dev and would not be for production.

## Runbook (order of work)

1. **Bootstrap the cluster and Argo CD.** Unzip the bundle into `~/vaultai`, run `./scripts/30-all-in-one.sh`. It builds the images inside minikube, pushes the chart and GitOps files to `main`, installs Argo CD and deploys the `vaultai-dev` app.
2. **Open the UIs.** Start `./scripts/22-argocd-ui.sh` (port 8080) and `./scripts/26-preview-open.sh dev` (port 9000) in the background.
3. **Prove self-heal.** `kubectl -n vaultai-dev scale deploy/api --replicas=3` is reverted by Argo CD.
4. **Prove GitOps.** Change `api.replicas` in `charts/vaultai-preview/values.yaml`, push, and the cluster follows. Revert the same way.
5. **Enable PR previews.** Create a fine-grained GitHub token (Contents read, Pull requests read/write), run `./scripts/23-argocd-github-token.sh` and `./scripts/24-argocd-apply.sh previews`, then `./scripts/25-demo-pr.sh`. Opening the PR creates `vaultai-pr-<N>`; closing it deletes the namespace.
6. **App-of-Apps.** Add `gitops/root.yaml`, `kubectl apply -f` it once. It now manages the dev Application, the ApplicationSet and the AppProject. Deleting the ApplicationSet by hand is recreated by the root.
7. **Manual sync demo.** Apply `demo/manual-sync/application.yaml` (no `automated` block). Git changes show `OutOfSync` but nothing deploys until Sync is clicked, and manual drift is not reverted.
8. **Install External Secrets Operator** as an Argo CD Application (`gitops/external-secrets.yaml`, chart 2.6.0, `ServerSideApply=true`).
9. **Secret store.** `platform/secret-store/` creates the `vault-source` namespace, a read-only ServiceAccount and Role, and a `ClusterSecretStore` using the Kubernetes provider. The source secret `vaultai-db-source` is created by hand and is not in Git.
10. **Switch the chart to an ExternalSecret.** Remove the generated `secret.yaml`, add `externalsecret.yaml`, and point the api and postgres Deployments at `vaultai-db-eso`.
11. **Fix the Postgres readiness probe** (error 10 above).
12. **Per-PR image tags.** `scripts/11-build-branch.sh` builds the images inside minikube tagged with the 8-character commit SHA. The ApplicationSet passes `{{.head_short_sha}}` to `images.api.tag` and `images.frontend.tag` (with `forceString`). Tested with a changed page title on a PR branch: the preview showed it, dev did not.
13. **Per-preview observability (light).** Pod template labels carry `vaultai.dev/pr`, so `kubectl logs -l vaultai.dev/pr=<N>` and `kubectl top pods -A -l vaultai.dev/pr=<N>` (with metrics-server) show one environment only. No Prometheus or Grafana, which would not fit the node.
14. **Cleanup.** Close the test PR without merging, stop the tunnels with `pkill -f port-forward`, and disable metrics-server if RAM is tight.
