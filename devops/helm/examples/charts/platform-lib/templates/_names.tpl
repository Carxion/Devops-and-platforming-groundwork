{{/*
Names and labels. Every chart that depends on platform-lib uses these, so
resources from every team carry the same recommended labels.
*/}}

{{/* The chart name, or nameOverride. */}}
{{- define "platform-lib.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The full name for resources: the release name, plus the chart name unless the
release name already contains it, or fullnameOverride. Kubernetes names are
limited to 63 characters for many fields, so it's truncated.
*/}}
{{- define "platform-lib.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* name-version, for the helm.sh/chart label. */}}
{{- define "platform-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels: what Deployments and Services select on. These two must never
change for a release, because a Deployment's selector is immutable.
*/}}
{{- define "platform-lib.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* All labels: the selector labels plus version, chart, and ownership. */}}
{{- define "platform-lib.labels" -}}
{{ include "platform-lib.selectorLabels" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "platform-lib.chart" . }}
{{- with .Values.partOf }}
app.kubernetes.io/part-of: {{ . }}
{{- end }}
{{- end }}

{{/*
The image reference, by digest. A tag can be moved to a different image; a
digest can't, so what was tested is what runs. The tag is optional and only
for people reading the manifest.
*/}}
{{- define "platform-lib.image" -}}
{{- $digest := required "image.digest is required (sha256:...): images are pinned by digest" .Values.image.digest }}
{{- if .Values.image.tag }}
{{- printf "%s:%s@%s" .Values.image.repository .Values.image.tag $digest }}
{{- else }}
{{- printf "%s@%s" .Values.image.repository $digest }}
{{- end }}
{{- end }}
