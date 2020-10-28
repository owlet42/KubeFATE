{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "rabbitmq-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rabbitmq-ha.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rabbitmq-ha.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "rabbitmq-ha.serviceAccountName" -}}
{{- if .Values.modules.rabbitmq.serviceAccount.create -}}
    {{ default (include "rabbitmq-ha.fullname" .) .Values.modules.rabbitmq.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.modules.rabbitmq.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Generate chart secret name
*/}}
{{- define "rabbitmq-ha.secretName" -}}
{{ default (include "rabbitmq-ha.fullname" .) .Values.existingSecret }}
{{- end -}}

{{/*
Generate chart ssl secret name
*/}}
{{- define "rabbitmq-ha.certSecretName" -}}
{{ default (print (include "rabbitmq-ha.fullname" .) "-cert") .Values.modules.rabbitmq.rabbitmqCert.existingSecret }}
{{- end -}}

{{/*
Defines a JSON file containing definitions of all broker objects (queues, exchanges, bindings, 
users, virtual hosts, permissions and parameters) to load by the management plugin.
*/}}
{{- define "rabbitmq-ha.definitions" -}}
{
  "global_parameters": [
{{ .Values.modules.rabbitmq.definitions.globalParameters | indent 4 }}
  ],
  "users": [
    {
      "name": {{ .Values.modules.rabbitmq.managementUsername | quote }},
      "password": {{ .Values.modules.rabbitmq.managementPassword | quote }},
      "tags": "management"
    },
    {
      "name": {{ .Values.modules.rabbitmq.rabbitmqUsername | quote }},
      "password": {{ .Values.modules.rabbitmq.rabbitmqPassword | quote }},
      "tags": "administrator"
    }{{- if .Values.modules.rabbitmq.definitions.users -}},
{{ .Values.modules.rabbitmq.definitions.users | indent 4 }}
{{- end }}
  ],
  "vhosts": [
    {
      "name": {{ .Values.modules.rabbitmq.rabbitmqVhost | quote }}
    }{{- if .Values.modules.rabbitmq.definitions.vhosts -}},
{{ .Values.modules.rabbitmq.definitions.vhosts | indent 4 }}
{{- end }}
  ],
  "permissions": [
    {
      "user": {{ .Values.modules.rabbitmq.rabbitmqUsername | quote }},
      "vhost": {{ .Values.modules.rabbitmq.rabbitmqVhost | quote }},
      "configure": ".*",
      "read": ".*",
      "write": ".*"
    }{{- if .Values.modules.rabbitmq.definitions.permissions -}},
{{ .Values.modules.rabbitmq.definitions.permissions | indent 4 }}
{{- end }}
  ],
  "parameters": [
{{.Values.modules.rabbitmq.definitions.parameters| indent 4 }}
  ],
  "policies": [
{{.Values.modules.rabbitmq.definitions.policies | indent 4 }}
  ],
  "queues": [
{{.Values.modules.rabbitmq.definitions.queues | indent 4 }}
  ],
  "exchanges": [
{{.Values.modules.rabbitmq.definitions.exchanges | indent 4 }}
  ],
  "bindings": [
{{.Values.modules.rabbitmq.definitions.bindings| indent 4 }}
  ]
}
{{- end -}}