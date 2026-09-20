# Day 1: Argo CD, ApplicationSets and per-PR preview environments

Study notes plus a short interview answer, tied to what is built in this repo.

## Core concepts

**Application (CRD).** One Argo CD `Application` says: take this Git path at this revision, render it (Helm, Kustomize or plain YAML), and deploy it to this cluster and namespace. Argo CD continuously compares the rendered manifests (desired state) with the live cluster (actual state).
In this repo: `gitops/application-dev.yaml` points at `charts/vaultai-preview` on `main`, destination namespace `vaultai-dev`.

**Two separate statuses.**
- **Sync status** is whether live matches Git: `Synced` or `OutOfSync`.
- **Health status** is whether the resources actually work: `Healthy`, `Progressing`, `Degraded`, `Missing`.
Watching the dev app go `OutOfSync/Healthy` → `Synced/Progressing` → `Synced/Healthy` shows both. `Progressing` lasted about a minute because the API pod was waiting for its readiness probe on `/healthz`.

**Sync policies.**
- **Manual:** Argo CD shows drift and waits for someone to click Sync. Safer for production changes that need a human gate.
- **Automated:** Argo CD syncs on its own when Git changes. Two options matter:
  - `prune: true` deletes cluster resources that were removed from Git.
  - `selfHeal: true` reverts manual changes made directly on the cluster.
This repo uses automated with both on (`{"automated":{"prune":true,"selfHeal":true}}`). Manual sync was not demonstrated.

**Health checks.** Argo CD has built-in health logic for standard Kubernetes resources (a Deployment is healthy when its rollout completes and pods pass readiness probes). Custom resources can get custom Lua health checks. The chart's `api.healthPath: /healthz` feeds the readiness probe, so a broken API keeps the app from reporting Healthy.

**App-of-Apps.** A root `Application` whose source is a directory of other `Application` manifests. Applying one root creates and manages all the children, which gives one bootstrap step and a Git-tracked list of everything Argo CD runs. **Built here:** `gitops/root.yaml` is a root Application over `gitops/`, so the dev Application, ApplicationSet and AppProject are all managed from Git.
ApplicationSet is the alternative for generating many similar Applications from a template, and the two are often combined (App-of-Apps for platform components, ApplicationSets for per-environment or per-PR apps).

## ApplicationSet and the Pull Request generator

An `ApplicationSet` is a controller and a template. **Generators** produce a list of parameter sets, and the template stamps out one `Application` per set.

The **Pull Request generator** calls the GitHub API, lists the repo's open PRs, and produces parameters for each one, such as `number`, `branch` and `head_sha`. The template uses them, for example:

- Application name `vaultai-pr-{{number}}`
- Destination namespace `vaultai-pr-{{number}}`
- Helm parameters that pass the PR number and branch into the chart

When a PR is closed or merged it disappears from the generator's list. The ApplicationSet controller then deletes the matching Application, and the resources-finalizer on it cascades the deletion to everything it deployed. That is why `vaultai-pr-1` went `Terminating` and vanished a couple of minutes after the PR was closed.

Detection works by polling (about 2 minutes here). The default requeue interval is much longer, so production setups configure a GitHub webhook to the ApplicationSet controller for near-instant reaction. To skip the wait in the demo, restart the controller: `kubectl -n argocd rollout restart deploy/argocd-applicationset-controller`.

## Why teams build preview environments

- Reviewers and QA test the real running change, not just a diff.
- Each PR is isolated, so two people never fight over one shared "staging".
- Integration problems (config, migrations, networking) show up before merge.
- The environment costs nothing while no PR is open, because teardown is automatic.
- The same chart and pipeline that ship to dev are exercised on every PR.

## Interview answer: "How would you design ephemeral preview environments per PR?"

> I'd let Git drive everything with an Argo CD ApplicationSet using the Pull Request generator. It watches the GitHub repo for open PRs, ideally via a webhook so it reacts immediately, with polling as a fallback. For each PR it generates an Application named after the PR number, which renders one shared Helm chart into its own namespace like `vaultai-pr-42`, with automated sync, prune and self-heal on.
>
> CI builds one image per commit, tagged with the PR's head SHA, and the ApplicationSet passes that tag into the chart, so the preview runs exactly the PR's code. An AppProject limits what these apps can deploy and where, and each namespace gets a resource quota so a preview can't starve the cluster.
>
> For secrets, I'd use External Secrets Operator. A `ClusterSecretStore` points at Vault or AWS Secrets Manager, and the chart includes an `ExternalSecret` per namespace that pulls preview-scoped credentials, so nothing sensitive is in Git and every preview gets its own database credentials. For observability, I'd label every workload with the PR number so logs, metrics and dashboards can be filtered per environment.
>
> Teardown is automatic. When the PR is merged or closed it drops out of the generator, the ApplicationSet deletes the Application, the finalizer cascades to the resources, and the namespace goes away. As a safety net, I'd add a TTL or cleanup job for anything orphaned.

## What is built here and what is not

| Topic | Status |
|---|---|
| Application CRD, automated sync with prune + self-heal | Built and tested |
| Health status and readiness probe on `/healthz` | Built and observed |
| ApplicationSet + Pull Request generator | Built and tested (open PR creates namespace, close PR removes it) |
| Per-PR isolated namespace with its own postgres and gateway | Built and tested |
| AppProject scoping previews | Built (`gitops/appproject-previews.yaml`) |
| Manual sync policy | Demonstrated (`demo/manual-sync`) |
| App-of-Apps (root Application over gitops/) | Built and tested |
| External Secrets Operator (ClusterSecretStore + ExternalSecret per environment) | Built and tested (Kubernetes provider as a stand-in for Vault) |
| Per-preview observability | Not built |
| Per-PR image tags from CI | Not built (images are `:local`, so previews don't reflect branch code) |
| GitHub webhook instead of polling | Not built |

When explaining this in an interview, say plainly which parts you implemented and which you can only design. The design answer above is accurate, and the table shows exactly where the implementation stops.
