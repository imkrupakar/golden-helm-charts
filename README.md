# golden-helm-charts

Centrally maintained by Platform Engineering. The `golden-service` chart encodes org
standards (progressive delivery via Argo Rollouts, probes, securityContext, PDB, HPA,
ServiceAccount for workload identity, ESO-backed secrets).

NetworkPolicy is platform-owned: the per-tenant default-deny + same-tenant-allow policy
created by `tenants-namespace` already covers ingress/egress for every service in that tenant's
namespace, and tenant AppProjects blacklist `NetworkPolicy` (see platform-tenants vs team-*
project boundary) — so the chart leaves that resource kind entirely to the platform.

Teams never copy this chart — they pin a **version per cluster** (`goldenChart` in their cluster leaf) and supply
only a thin `values.yaml` overlay. A release therefore reaches a team only when that team upgrades, so what is
published must be trustworthy and well described: see *Versioning and releases* below.

```
support-policy.yaml              # which versions teams may pin (min / latest / deprecated)
CHANGELOG.md                    # SemVer rules + one entry per release
tests/                          # render_scenarios.sh (regressions), check_policy.sh
.github/workflows/              # ci.yml (PR), publish-chart.yml (tag, immutable)
charts/golden-service/
├── Chart.yaml
├── values.yaml                # safe org defaults
└── templates/
    ├── _helpers.tpl
    ├── serviceaccount.yaml
    ├── rollout.yaml           # Argo Rollouts canary (falls back to Deployment if disabled)
    ├── service.yaml
    ├── httproute.yaml         # Gateway API HTTPRoute, attaches to the shared platform Istio Gateway
    ├── hpa.yaml
    ├── pdb.yaml
    └── externalsecret.yaml    # pulls app secrets from the tenant ESO SecretStore
charts/platform-config/        # platform cluster-wide config, pinned per cluster (platformConfig)
└── templates/                 #   Istio Gateway + tenant SecretStore admission guard (toggleable)
```

This repo holds **two** charts: `golden-service` (what teams deploy, below) and `platform-config`
(platform cluster-wide config — the shared Istio Gateway and the SecretStore admission guard —
pinned per cluster via `platformConfig` and promoted like the add-ons; owned by Platform Engineering).

## Cloud-neutral by design

The chart holds no cloud-specific values. The platform ApplicationSet injects the cluster's
identity as `global.cloud`, `global.region` and `global.environment`, and the chart derives the
cloud-specific bits from it (today: the `azure.workload.identity/use` label on the ServiceAccount
and pod when `global.cloud=azure`; see `golden-service.identityLabels`). Identity IDs/ARNs and the
image registry are supplied by the team's cloud/leaf overlay (`serviceAccount.annotations`,
`image.repository`). Teams must not set `global.*`.

Published to an OCI registry by `.github/workflows/publish-chart.yml` on tag.

## Versioning and releases

- **SemVer, strictly** (rules in `CHANGELOG.md`): removing/renaming a value or a rendered resource, or needing a newer
  add-on API, is a MAJOR; new optional values are MINOR; bug fixes are PATCH.
- **Every release** adds a `CHANGELOG.md` entry, bumps `charts/golden-service/Chart.yaml`, and updates `support-policy.yaml`
  (`latest`); `tests/check_policy.sh` fails CI if they disagree.
- **`support-policy.yaml`** is what teams are checked against on every PR: they may pin `minimumSupported` ..= `latest`
  (`deprecated` versions get a warning). Raising `minimumSupported` is how an old version is retired.
- **Published versions are immutable**: `publish-chart.yml` refuses to overwrite an existing OCI version.
- **Tests** (`tests/render_scenarios.sh`, run on every PR and before publishing) render the situations that have
  bitten us: HPA vs `replicas`, a PDB that would block drains, the TLS issuer annotation, the cloud identity label and the
  image reference. Add a scenario with every bug fix.
- **Chart source:** published to `oci://ghcr.io/imkrupakar/charts/golden-service`; Argo CD reaches it through the
  repository declared in `platform-gitops/argocd/base/repo-golden-charts.yaml`.

