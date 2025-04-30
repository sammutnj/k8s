{{- define "nginx-chart.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "nginx-chart.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

{{- define "nginx-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: {{ .Values.app }}
{{- end }}

{{- define "nginx-chart.selectorLabels" -}}
app: {{ .Values.app }}
{{- end }}
