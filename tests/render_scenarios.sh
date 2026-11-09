#!/usr/bin/env bash
# Render the chart for the situations that have bitten us and assert on the OUTPUT.
# Needs helm and yq. Run from anywhere:  golden-helm-charts/tests/render_scenarios.sh
set -uo pipefail
CHART="${CHART_DIR:-$(cd "$(dirname "$0")/.." && pwd)/charts/golden-service}"
pass=0; fail=0

render() { helm template t "$CHART" -n team-x --set image.repository=reg.example/app --set image.tag=1.0.0 "$@" 2>&1; }
# count of rendered objects of a kind
count() { printf '%s' "$1" | yq "select(.kind == \"$2\") | .kind" | grep -c . || true; }
# a yq expression against one kind, "absent" when null
field() { printf '%s' "$1" | yq "select(.kind == \"$2\") | ($3) // \"absent\"" | head -1; }
expect() { # name expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok    %s\n' "$1"; else fail=$((fail+1)); printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$2" "$3"; fi
}

echo "HPA owns replicas (Argo CD selfHeal must not fight it)"
o=$(render --set replicaCount=4 --set autoscaling.enabled=true --set autoscaling.minReplicas=4 --set autoscaling.maxReplicas=12)
expect "autoscaled: Rollout has no spec.replicas"      absent  "$(field "$o" Rollout .spec.replicas)"
expect "autoscaled: HPA rendered"                      1       "$(count "$o" HorizontalPodAutoscaler)"
expect "autoscaled: HPA targets the Rollout"           Rollout "$(field "$o" HorizontalPodAutoscaler .spec.scaleTargetRef.kind)"
o=$(render --set replicaCount=3 --set autoscaling.enabled=false)
expect "static: Rollout keeps spec.replicas"           3       "$(field "$o" Rollout .spec.replicas)"
expect "static: no HPA"                                0       "$(count "$o" HorizontalPodAutoscaler)"
o=$(render --set rollout.enabled=false --set autoscaling.enabled=true)
expect "no-rollout: kind is Deployment"                1       "$(count "$o" Deployment)"
expect "no-rollout: Deployment has no spec.replicas"   absent  "$(field "$o" Deployment .spec.replicas)"
expect "no-rollout: HPA targets the Deployment"        Deployment "$(field "$o" HorizontalPodAutoscaler .spec.scaleTargetRef.kind)"

echo "PDB must never block every eviction"
o=$(render --set replicaCount=1 --set autoscaling.enabled=false)
expect "1 replica, minAvailable 1: no PDB"             0       "$(count "$o" PodDisruptionBudget)"
o=$(render --set replicaCount=3 --set autoscaling.enabled=false)
expect "3 replicas: PDB rendered"                      1       "$(count "$o" PodDisruptionBudget)"
o=$(render --set autoscaling.enabled=true --set autoscaling.minReplicas=1)
expect "HPA floor 1: no PDB"                           0       "$(count "$o" PodDisruptionBudget)"
o=$(render --set autoscaling.enabled=true --set autoscaling.minReplicas=4)
expect "HPA floor 4: PDB rendered"                     1       "$(count "$o" PodDisruptionBudget)"
o=$(render --set replicaCount=1 --set autoscaling.enabled=false --set pdb.minAvailable=50%)
expect "percentage minAvailable: PDB rendered"         1       "$(count "$o" PodDisruptionBudget)"
o=$(render --set pdb.enabled=false --set replicaCount=5)
expect "pdb.enabled=false: no PDB"                     0       "$(count "$o" PodDisruptionBudget)"

echo "Gateway API HTTPRoute"
o=$(render --set route.enabled=true --set route.host=a.example.com)
expect "route on: HTTPRoute rendered"                  1        "$(count "$o" HTTPRoute)"
expect "route host set"                                a.example.com "$(field "$o" HTTPRoute '.spec.hostnames[0]')"
expect "route attaches to platform gateway"            platform-gateway "$(field "$o" HTTPRoute '.spec.parentRefs[0].name')"
o=$(render)
expect "route off (default): no HTTPRoute"             0        "$(count "$o" HTTPRoute)"
o=$(render --set route.enabled=true --set route.host=a.example.com)
expect "no Ingress rendered anymore"                   0        "$(count "$o" Ingress)"

echo "Cloud identity label comes from global.cloud"
o=$(render --set global.cloud=azure)
expect "azure: pod has workload-identity label"        true    "$(field "$o" Rollout '.spec.template.metadata.labels."azure.workload.identity/use"')"
o=$(render --set global.cloud=aws)
expect "aws: no azure label on the pod"                absent  "$(field "$o" Rollout '.spec.template.metadata.labels."azure.workload.identity/use"')"

echo "Image reference"
o=$(render --set image.digest=sha256:abc)
expect "tag + digest render together"                  "reg.example/app:1.0.0@sha256:abc" "$(field "$o" Rollout '.spec.template.spec.containers[0].image')"

echo; echo "passed=$pass failed=$fail"; [ "$fail" -eq 0 ]
