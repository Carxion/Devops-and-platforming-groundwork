{{/*
Whole resources that are the same in every workload chart. A chart renders
one with, for example:

  {{ include "platform-lib.serviceAccount" . }}
*/}}

{{/* A service account with no API token mounted: these workloads don't call the Kubernetes API. */}}
{{- define "platform-lib.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "platform-lib.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "platform-lib.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: false
{{- end }}

{{/* Node drains and upgrades take down at most podDisruptionBudget.maxUnavailable pods at a time. */}}
{{- define "platform-lib.podDisruptionBudget" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "platform-lib.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "platform-lib.labels" . | nindent 4 }}
spec:
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  selector:
    matchLabels:
      {{- include "platform-lib.selectorLabels" . | nindent 6 }}
{{- end }}

{{/*
DNS egress to CoreDNS, as a NetworkPolicy egress rule. Charts add it to their
own policy, so the chart works in a default-deny namespace with or without a
namespace-wide DNS policy.
*/}}
{{- define "platform-lib.dnsEgressRule" -}}
- to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
  ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
{{- end }}
