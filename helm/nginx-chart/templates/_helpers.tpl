{{- define "nginx-chart.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "nginx-chart.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}
