{{- define "golden-service.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "golden-service.labels" -}}
app.kubernetes.io/name: {{ include "golden-service.name" . }}
app.kubernetes.io/managed-by: argocd
app.kubernetes.io/part-of: {{ .Release.Namespace }}
{{- end -}}

{{- define "golden-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "golden-service.name" . }}
{{- end -}}

{{/*
Fully-qualified image reference. Build-once / promote-many: the SemVer tag is human-readable
and the digest (when set) is verified on pull for immutability. Renders:
  repo:tag@sha256:...   when both tag and digest are set
  repo@sha256:...       when only digest is set
  repo:tag              when only tag is set
*/}}
{{- define "golden-service.image" -}}
{{- $repo := required "image.repository is required" .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{- $digest := .Values.image.digest | default "" | toString -}}
{{- if $digest -}}
{{- if $tag -}}{{ printf "%s:%s@%s" $repo $tag $digest }}{{- else -}}{{ printf "%s@%s" $repo $digest }}{{- end -}}
{{- else -}}
{{- if not $tag -}}{{ fail "image.tag or image.digest must be set" }}{{- end -}}
{{ printf "%s:%s" $repo $tag }}
{{- end -}}
{{- end -}}

{{/*
Workload-identity labels, applied to BOTH the ServiceAccount and the pod template.
The cloud-specific label is derived from global.cloud (injected from the cluster's `cloud`
label), so teams never hardcode it. serviceAccount.labels adds team-supplied extras.
*/}}
{{- define "golden-service.identityLabels" -}}
{{- $g := .Values.global | default dict -}}
{{- if eq ($g.cloud | default "") "azure" }}
azure.workload.identity/use: "true"
{{- end }}
{{- with .Values.serviceAccount.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Lowest number of replicas the workload will run with: the HPA floor when autoscaling is on,
else replicaCount. Used to avoid rendering a PodDisruptionBudget that blocks every eviction.
*/}}
{{- define "golden-service.minReplicas" -}}
{{- if .Values.autoscaling.enabled -}}{{ .Values.autoscaling.minReplicas }}{{- else -}}{{ .Values.replicaCount }}{{- end -}}
{{- end -}}

