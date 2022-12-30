#######################################################
###############        GENERAL       ##################
#######################################################

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to
this (by the DNS naming spec). If release name contains chart name it will
be used as a full name.
*/}}
{{- define "example-backend.fullname" -}}
{{- if ne (.Values.global.projectName | toString) "" -}}
{{- .Values.global.projectName | trunc 63 | trimSuffix "-" -}}
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
{{- define "example-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "example-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
#######################################################
###############         back          ##################
#######################################################


{{/*
Set's the replica count based on the different modes configured by user
*/}}
{{- define "back.replicas" -}}
  {{ if eq .mode "ha" }}
    {{- .Values.back.ha.replicas | default 3 -}}
  {{ else }}
    {{- default 1 -}}
  {{ end }}
{{- end -}}

{{/*
Inject extra environment vars in the format key:value, if populated
*/}}
{{- define "back.extraEnvironmentVars" -}}
{{- if .extraEnvironmentVars -}}
{{- range $key, $value := .extraEnvironmentVars }}
- name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}
{{/*
Inject extra environment populated by secrets, if populated
*/}}
{{- define "back.extraSecretEnvironmentVars" -}}
{{- if .extraSecretEnvironmentVars -}}
{{- range .extraSecretEnvironmentVars }}
- name: {{ .envName }}
  valueFrom:
   secretKeyRef:
     name: {{ .secretName }}
     key: {{ .secretKey }}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Set's the node selector for pod placement when running in standalone and HA modes.
*/}}
{{- define "back.nodeselector" -}}
{{- if .Values.back.nodeSelector -}}
  nodeSelector: {{ toYaml .Values.back.nodeSelector | nindent 8 }}
{{ end }}
{{- end -}}


{{/*
Set's the affinity for pod placement when running in standalone and HA modes.
*/}}
{{- define "back.affinity" -}}
{{- end -}}

{{/*
Sets the back toleration for pod placement
*/}}
{{- define "back.tolerations" -}}
  {{- if .Values.back.tolerations }}
      tolerations:
        {{ tpl .Values.back.tolerations . | nindent 8 | trim }}
  {{- end }}
{{- end -}}

{{/*
Sets extra ingress annotations
*/}}
{{- define "back.ingress.annotations" -}}
  {{- if .Values.back.ingress.annotations }}
  annotations:
    {{- tpl .Values.back.ingress.annotations . | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "back.resources" -}}
  {{- if .Values.back.resources -}}
          resources:
{{ toYaml .Values.back.resources | indent 12}}
  {{ else }}
  {{ end }}
{{- end -}}


{{/*
Set's up configmap mounts if this isn't a dev deployment and the user
defined a custom configuration.  Additionally iterates over any
extra volumes the user may have specified (such as a secret with TLS).
*/}}
{{- define "back.volumes" -}}
  {{ if .Values.back.extraVolumes }}
      volumes:
    {{- range .Values.back.extraVolumes }}
      - name: {{ .name }}
        {{ .type }}:
        {{- if (eq .type "configMap") }}
          name: {{ .name }}
        {{- else if (eq .type "secret") }}
          secretName: {{ .name }}
        {{- end }}
    {{- end }}
  {{ end }}
{{- end -}}

{{/*
Set's which additional volumes should be mounted to the container
based on the mode configured.
*/}}
{{- define "back.mounts" -}}
  {{ if .Values.back.extraVolumes }}
          volumeMounts:
    {{- range .Values.back.extraVolumes }}
          - name: {{ .name }}
            readOnly: true
            mountPath: {{ .path | default "/mnt" }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "back.hostAliases" -}}
  {{- if .Values.back.hostAliases -}}
      hostAliases:
    {{- tpl .Values.back.hostAliases . | nindent 6 }}
  {{ else }}
  {{ end }}
{{- end -}}



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# worker1      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "worker1.resources" -}}
  {{- if .worker1.resources -}}
          resources:
{{ toYaml .worker1.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.worker1.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.worker1" -}}
{{- if .worker1.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .worker1.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
    spec:
      terminationGracePeriodSeconds: {{ .worker1.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .worker1.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.worker1.command }}
          command: {{- toYaml .Values.worker1.command | nindent 10 }}
          args: {{ .Values.worker1.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .worker1.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .worker1.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .worker1.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .worker1.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "worker1.resources" . }}
          {{- if .Values.worker1.envFrom }}
          envFrom:
          {{- toYaml .Values.worker1.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .worker1.extraEnvironmentVars -}}
          {{- range $key, $value := .worker1.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .worker1.nodeSelector }}
      nodeSelector:
        {{ toYaml .worker1.nodeSelector }}
    {{ else if .Values.worker1.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.worker1.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.worker1.hpa" -}}
  {{- if .worker1.enabled -}}
  {{- if .worker1.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
  minReplicas: {{ .worker1.hpa.min }}
  maxReplicas: {{ .worker1.hpa.max }}
  targetCPUUtilizationPercentage: {{ .worker1.hpa.cpuPorcentage }}
---
  {{- else if .Values.worker1.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .worker1.name }}
  minReplicas: {{ .Values.worker1.hpa.min }}
  maxReplicas: {{ .Values.worker1.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.worker1.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}

