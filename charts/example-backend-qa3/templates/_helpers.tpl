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
# w1      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "w1.resources" -}}
  {{- if .w1.resources -}}
          resources:
{{ toYaml .w1.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.w1.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.w1" -}}
{{- if .w1.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .w1.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
    spec:
      terminationGracePeriodSeconds: {{ .w1.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .w1.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.w1.command }}
          command: {{- toYaml .Values.w1.command | nindent 10 }}
          args: {{ .Values.w1.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .w1.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .w1.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .w1.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .w1.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "w1.resources" . }}
          {{- if .Values.w1.envFrom }}
          envFrom:
          {{- toYaml .Values.w1.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .w1.extraEnvironmentVars -}}
          {{- range $key, $value := .w1.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .w1.nodeSelector }}
      nodeSelector:
        {{ toYaml .w1.nodeSelector }}
    {{ else if .Values.w1.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.w1.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.w1.hpa" -}}
  {{- if .w1.enabled -}}
  {{- if .w1.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
  minReplicas: {{ .w1.hpa.min }}
  maxReplicas: {{ .w1.hpa.max }}
  targetCPUUtilizationPercentage: {{ .w1.hpa.cpuPorcentage }}
---
  {{- else if .Values.w1.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .w1.name }}
  minReplicas: {{ .Values.w1.hpa.min }}
  maxReplicas: {{ .Values.w1.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.w1.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}

