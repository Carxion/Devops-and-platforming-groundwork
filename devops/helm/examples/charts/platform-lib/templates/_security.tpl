{{/*
The hardened defaults every workload runs with, matching the Pod Security
"restricted" profile and devops/kubernetes: a fixed non-root user, the
runtime's default seccomp profile, no privilege escalation, a read-only root
filesystem, and no Linux capabilities. Charts include these instead of
writing their own, so a fix here reaches every chart on its next upgrade.
*/}}

{{- define "platform-lib.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "platform-lib.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}
