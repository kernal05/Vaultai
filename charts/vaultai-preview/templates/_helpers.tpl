{{- define "vp.labels" -}}
app.kubernetes.io/part-of: vaultai
vaultai.dev/pr: {{ .Values.preview.prNumber | quote }}
vaultai.dev/commit: {{ .Values.preview.commit | quote }}
{{- end }}

{{/* Labels on the PODS (not the Deployments). No commit label on purpose: the commit changes on every
     push, and a changed pod template would restart every pod, including postgres, on every push. */}}
{{- define "vp.podLabels" -}}
app.kubernetes.io/part-of: vaultai
vaultai.dev/pr: {{ .Values.preview.prNumber | quote }}
{{- end }}
