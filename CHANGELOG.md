# golden-service changelog

Versioning is SemVer, and teams pin a version per cluster leaf (`goldenChart`), so what counts as
a breaking change matters:

- **MAJOR**: removes or renames a value, removes a rendered resource, changes a default so that an
  existing overlay renders something different on purpose, or needs a newer add-on API
  (for example moving ExternalSecret from `v1beta1` to `v1`).
- **MINOR**: adds an optional value or resource; existing overlays render the same.
- **PATCH**: fixes a bug without changing the values contract.

Every release adds an entry here (CI checks), updates `support-policy.yaml`, and is published as an
immutable OCI version (the publish job refuses to overwrite an existing version).

## [3.0.0]
### Changed (breaking)
- **`ExternalSecret` moved from `external-secrets.io/v1beta1` to `external-secrets.io/v1`.** Requires an
  External Secrets Operator that serves the `v1` API. ESO no longer serves `v1beta1` by default (the
  compatibility flag was removed upstream), so this needs the newer add-on API.
### Upgrade notes
- Bump the `external-secrets` add-on pin to `2.13.0` (ESO app `v2.13.0`) in each cluster's
  `versions.yaml`, then re-pin `goldenChart: "3.0.0"` in the cluster leaves. Team-owned `SecretStore`
  manifests must also move to `external-secrets.io/v1` — the field layout is unchanged, only the
  `apiVersion`.

## [2.7.0]
### Changed (breaking)
- **North-south routing moved from nginx `Ingress` to the Kubernetes Gateway API.** The chart now
  renders an `HTTPRoute` (attached to the shared platform Istio `Gateway`) instead of an `Ingress`.
  TLS is terminated at the external L7 load balancer, so no TLS/cert is configured in the chart.
### Removed
- `ingress.*` values (`enabled`, `className`, `host`, `tls`, `clusterIssuer`) and the
  `cert-manager.io/cluster-issuer` annotation (cert-manager is no longer used).
### Added
- `route.*` values: `enabled`, `host`, `path`, and `gateway.{name,namespace,sectionName}`.
### Upgrade notes
- Replace `ingress:` overlays with `route:`. Example: `route.enabled=true`, `route.host=app.example.com`.
  Certificates are handled by the L7 LB, not the chart.

## [2.6.0]
### Added
- `ingress.clusterIssuer`: adds the `cert-manager.io/cluster-issuer` annotation so TLS certificates
  are actually requested (previously the Ingress named a TLS secret that nothing created).
### Fixed
- **HPA vs Argo CD**: `spec.replicas` is no longer rendered when `autoscaling.enabled=true`.
  Before, `selfHeal` kept resetting the replica count the HPA had scaled to.
- **PDB blocking drains**: no PodDisruptionBudget is rendered when `minAvailable` is not below the
  minimum replica count (for example 1 replica with `minAvailable: 1`).
### Upgrade notes
- Moving an autoscaled workload to this version drops `replicas` from the Rollout/Deployment
  manifest, so replicas may reset to 1 once before the HPA scales back to `minReplicas`. Upgrade
  sbx and dev first and keep `minReplicas` >= 2 for production workloads.
- Teams that want certificates set `ingress.clusterIssuer` (for example `letsencrypt-prod`).

## [2.5.0]
### Changed
- Cloud-neutral chart: the workload-identity label is derived from `global.cloud`
  (injected by the ApplicationSet). `serviceAccount.labels` no longer carries an Azure default.
- `image.repository` has no default (it is required).
### Removed (breaking, shipped as a minor)
- The per-service NetworkPolicy template. NetworkPolicy is platform-owned (`tenants-infra`), and
  tenant AppProjects blacklist the kind. By the rules above this should have been a major release;
  it is recorded here so the history is honest.

## [2.4.0]
Baseline for this changelog.
