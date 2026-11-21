{{- define "demo.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "demo.selectorLabels" -}}
app.kubernetes.io/name: demo-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "demo.labels" -}}
{{ include "demo.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}
