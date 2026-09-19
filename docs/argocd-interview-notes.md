# Argo CD + PR preview environments — interview notes

## Honest framing (say this first)
"I haven't run this at Kutumb's scale. I built a small replica of the pattern on minikube for my Crafto-style
project (VaultAI) so I'd understand the moving parts, and I can walk you through what I'd change for production."

## Core concepts (know these cold)
- **Application** – CRD: source (repo/path/revision) + destination (cluster/namespace) + sync policy.
- **AppProject** – guardrail: allowed repos, allowed destination namespaces, allowed cluster-scoped kinds.
- **Sync status vs Health status** – Synced/OutOfSync = Git vs live. Healthy/Progressing/Degraded = is it actually working.
- **Reconcile loop** – repo-server renders manifests from Git; application-controller diffs desired vs live; repo polled ~3 min (webhook = instant).
- **automated.prune** – delete resources removed from Git. **selfHeal** – revert manual `kubectl` drift.
- **Sync waves / hooks** – ordering (namespace -1 before workloads), PreSync DB migrations, PostSync smoke tests.
- **App-of-Apps vs ApplicationSet** – app-of-apps = a parent app whose manifests are child Apps (static, hand-written).
  ApplicationSet = a *generator* that stamps out Apps from data (list, cluster, git dirs, **pullRequest**, matrix).
- **Pull-based CD** – cluster pulls from Git; CI never holds cluster credentials.

## "Design ephemeral preview envs per PR" — 60-second answer
1. ApplicationSet with the **pullRequest generator** polls (or is webhook-triggered by) GitHub for open PRs.
2. Per PR it templates an Application: name `app-pr-<n>`, namespace `pr-<n>`, chart read from the PR's head SHA.
3. CI builds and pushes an image tagged with the PR SHA; the SHA is passed as a Helm parameter.
4. Secrets come from External Secrets (Vault) into each namespace — nothing in Git.
5. Observability: namespace/PR labels on everything so Prometheus/Grafana/Loki can filter per preview.
6. Cleanup: PR closes -> generator drops it -> Application deleted -> finalizer cascades -> namespace gone.
7. Guardrails: AppProject (limits blast radius), ResourceQuota per namespace, optional `preview` label gate, TTL/cron sweeper for stragglers.

## Follow-up questions to expect
- *Polling vs webhook?* Polling is the fallback (GitHub rate limits: use a token). Webhook to the applicationset-controller gives seconds-level latency.
- *How do you avoid preview envs blowing the AWS bill?* Quotas, label-gate, small requests, Karpenter spot nodes for the preview pool, TTL.
- *DB per PR?* Ephemeral postgres seeded from a fixture (what I did) vs a shared DB with per-PR schema; trade-off = fidelity vs cost.
- *Where do image builds happen?* CI (Jenkins/GitHub Actions) — Argo only deploys, never builds.
- *What if Argo and someone `kubectl edit` fight?* selfHeal reverts; `ignoreDifferences` for fields controllers mutate (HPA replicas, my random secret).

## What I'd do differently in prod (shows maturity)
Webhook not polling · ExternalSecret not chart-generated secret · CI-built per-SHA images · HTTPRoute/Ingress with a
wildcard host `pr-<n>.preview.example.com` (external-dns) · dedicated preview node pool · SSO + RBAC on Argo.
