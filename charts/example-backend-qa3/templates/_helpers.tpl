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
# ooo      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "ooo.resources" -}}
  {{- if .ooo.resources -}}
          resources:
{{ toYaml .ooo.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.ooo.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.ooo" -}}
{{- if .ooo.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .ooo.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
    spec:
      terminationGracePeriodSeconds: {{ .ooo.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .ooo.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.ooo.command }}
          command: {{- toYaml .Values.ooo.command | nindent 10 }}
          args: {{ .Values.ooo.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .ooo.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .ooo.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .ooo.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .ooo.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "ooo.resources" . }}
          {{- if .Values.ooo.envFrom }}
          envFrom:
          {{- toYaml .Values.ooo.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .ooo.extraEnvironmentVars -}}
          {{- range $key, $value := .ooo.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .ooo.nodeSelector }}
      nodeSelector:
        {{ toYaml .ooo.nodeSelector }}
    {{ else if .Values.ooo.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.ooo.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.ooo.hpa" -}}
  {{- if .ooo.enabled -}}
  {{- if .ooo.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
  minReplicas: {{ .ooo.hpa.min }}
  maxReplicas: {{ .ooo.hpa.max }}
  targetCPUUtilizationPercentage: {{ .ooo.hpa.cpuPorcentage }}
---
  {{- else if .Values.ooo.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ooo.name }}
  minReplicas: {{ .Values.ooo.hpa.min }}
  maxReplicas: {{ .Values.ooo.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.ooo.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# eeee      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "eeee.resources" -}}
  {{- if .eeee.resources -}}
          resources:
{{ toYaml .eeee.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.eeee.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.eeee" -}}
{{- if .eeee.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .eeee.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
    spec:
      terminationGracePeriodSeconds: {{ .eeee.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .eeee.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.eeee.command }}
          command: {{- toYaml .Values.eeee.command | nindent 10 }}
          args: {{ .Values.eeee.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .eeee.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .eeee.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .eeee.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .eeee.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "eeee.resources" . }}
          {{- if .Values.eeee.envFrom }}
          envFrom:
          {{- toYaml .Values.eeee.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .eeee.extraEnvironmentVars -}}
          {{- range $key, $value := .eeee.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .eeee.nodeSelector }}
      nodeSelector:
        {{ toYaml .eeee.nodeSelector }}
    {{ else if .Values.eeee.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.eeee.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.eeee.hpa" -}}
  {{- if .eeee.enabled -}}
  {{- if .eeee.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
  minReplicas: {{ .eeee.hpa.min }}
  maxReplicas: {{ .eeee.hpa.max }}
  targetCPUUtilizationPercentage: {{ .eeee.hpa.cpuPorcentage }}
---
  {{- else if .Values.eeee.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .eeee.name }}
  minReplicas: {{ .Values.eeee.hpa.min }}
  maxReplicas: {{ .Values.eeee.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.eeee.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}

