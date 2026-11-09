#!/usr/bin/env bash
# Namespace contract guard for the platform-config umbrella chart.
#
# platform-config may carry resources for ANY namespace, so the invariant is: every *namespaced*
# resource MUST set its own metadata.namespace; only genuinely cluster-scoped kinds may omit it.
# The Argo Application's destination namespace is just the Helm release home (platform-system) and
# must never be relied on for placement. This script renders the chart across its toggle scenarios
# and fails if any namespaced resource is missing metadata.namespace.
#
# Requires: helm, yq (mikefarah v4). Run from the repo root.
set -euo pipefail

CHART="${1:-charts/platform-config}"

# Kinds that are cluster-scoped and legitimately have no metadata.namespace.
CLUSTER_SCOPED=$(cat <<'EOF'
Namespace Node PersistentVolume
ClusterRole ClusterRoleBinding
CustomResourceDefinition APIService
ValidatingWebhookConfiguration MutatingWebhookConfiguration
ValidatingAdmissionPolicy ValidatingAdmissionPolicyBinding
MutatingAdmissionPolicy MutatingAdmissionPolicyBinding
PriorityClass StorageClass VolumeAttachment CSIDriver CSINode
IngressClass GatewayClass RuntimeClass
FlowSchema PriorityLevelConfiguration
ClusterIssuer CertificateSigningRequest
EOF
)
is_cluster_scoped() { grep -qiw -- "$1" <<<"$CLUSTER_SCOPED"; }

fail=0
check() {
  local desc="$1"; shift
  # One "kind\tnamespace" line per rendered document.
  local line kind ns
  while IFS=$'\t' read -r kind ns; do
    [ -n "$kind" ] && [ "$kind" != "null" ] || continue
    is_cluster_scoped "$kind" && continue
    if [ -z "$ns" ] || [ "$ns" = "null" ]; then
      echo "::error::[$desc] namespaced resource '$kind' has no metadata.namespace"
      fail=1
    fi
  done < <(helm template pc "$CHART" "$@" | yq '[.kind, (.metadata.namespace // "")] | @tsv' 2>/dev/null)
}

# Render the toggle scenarios so enabled AND disabled paths are both checked.
check "default"
check "gateway-off"  --set istioGateway.enabled=false
check "guard-off"    --set secretstoreGuard.enabled=false
check "guard-warn"   --set 'secretstoreGuard.validationActions={Warn}'

if [ "$fail" -eq 0 ]; then
  echo "OK: every namespaced resource in $CHART sets metadata.namespace"
fi
exit "$fail"
