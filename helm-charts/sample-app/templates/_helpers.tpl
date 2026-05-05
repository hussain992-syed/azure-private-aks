{{/*
Expand the name of the chart.
*/}}
{{- define "sample-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sample-app.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sample-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sample-app.labels" -}}
helm.sh/chart: {{ include "sample-app.chart" . }}
{{ include "sample-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sample-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sample-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "sample-app.serviceAccountName" -}}
{{- if .Values.workloadIdentity.enabled }}
{{- default "default" .Values.workloadIdentity.serviceAccount.name }}
{{- else }}
{{- "default" }}
{{- end }}
{{- end }}

{{/*
Get the active color
*/}}
{{- define "sample-app.activeColor" -}}
{{- default "blue" .Values.deployment.activeColor }}
{{- end }}

{{/*
Get the inactive color
*/}}
{{- define "sample-app.inactiveColor" -}}
{{- if eq (include "sample-app.activeColor" .) "blue" }}green{{- else }}blue{{- end }}
{{- end }}

{{/*
Image tag for blue deployment
*/}}
{{- define "sample-app.blueImageTag" -}}
{{- if .Values.deployment.blue.imageTag }}
{{- .Values.deployment.blue.imageTag }}
{{- else }}
{{- .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Image tag for green deployment
*/}}
{{- define "sample-app.greenImageTag" -}}
{{- if .Values.deployment.green.imageTag }}
{{- .Values.deployment.green.imageTag }}
{{- else }}
{{- .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Blue deployment name
*/}}
{{- define "sample-app.blueName" -}}
{{- printf "%s-blue" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Green deployment name
*/}}
{{- define "sample-app.greenName" -}}
{{- printf "%s-green" (include "sample-app.fullname" .) }}
{{- end }}

{{/*
Client ID for workload identity
*/}}
{{- define "sample-app.clientId" -}}
{{- index .Values.workloadIdentity.serviceAccount.annotations "azure.workload.identity/client-id" -}}
{{- end }}
