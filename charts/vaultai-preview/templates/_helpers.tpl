{{- define "vp.labels" -}}
app.kubernetes.io/part-of: vaultai
vaultai.dev/pr: {{ .Values.preview.prNumber | quote }}
vaultai.dev/commit: {{ .Values.preview.commit | quote }}
{{- end }}
