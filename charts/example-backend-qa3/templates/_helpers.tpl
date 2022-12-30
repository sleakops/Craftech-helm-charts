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
# uuu      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "uuu.resources" -}}
  {{- if .uuu.resources -}}
          resources:
{{ toYaml .uuu.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.uuu.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.uuu" -}}
{{- if .uuu.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .uuu.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
    spec:
      terminationGracePeriodSeconds: {{ .uuu.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .uuu.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.uuu.command }}
          command: {{- toYaml .Values.uuu.command | nindent 10 }}
          args: {{ .Values.uuu.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .uuu.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .uuu.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .uuu.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .uuu.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "uuu.resources" . }}
          {{- if .Values.uuu.envFrom }}
          envFrom:
          {{- toYaml .Values.uuu.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .uuu.extraEnvironmentVars -}}
          {{- range $key, $value := .uuu.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .uuu.nodeSelector }}
      nodeSelector:
        {{ toYaml .uuu.nodeSelector }}
    {{ else if .Values.uuu.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.uuu.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.uuu.hpa" -}}
  {{- if .uuu.enabled -}}
  {{- if .uuu.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
  minReplicas: {{ .uuu.hpa.min }}
  maxReplicas: {{ .uuu.hpa.max }}
  targetCPUUtilizationPercentage: {{ .uuu.hpa.cpuPorcentage }}
---
  {{- else if .Values.uuu.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .uuu.name }}
  minReplicas: {{ .Values.uuu.hpa.min }}
  maxReplicas: {{ .Values.uuu.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.uuu.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# iiii      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "iiii.resources" -}}
  {{- if .iiii.resources -}}
          resources:
{{ toYaml .iiii.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.iiii.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.iiii" -}}
{{- if .iiii.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .iiii.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
    spec:
      terminationGracePeriodSeconds: {{ .iiii.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .iiii.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.iiii.command }}
          command: {{- toYaml .Values.iiii.command | nindent 10 }}
          args: {{ .Values.iiii.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .iiii.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .iiii.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .iiii.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .iiii.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "iiii.resources" . }}
          {{- if .Values.iiii.envFrom }}
          envFrom:
          {{- toYaml .Values.iiii.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .iiii.extraEnvironmentVars -}}
          {{- range $key, $value := .iiii.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .iiii.nodeSelector }}
      nodeSelector:
        {{ toYaml .iiii.nodeSelector }}
    {{ else if .Values.iiii.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.iiii.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.iiii.hpa" -}}
  {{- if .iiii.enabled -}}
  {{- if .iiii.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
  minReplicas: {{ .iiii.hpa.min }}
  maxReplicas: {{ .iiii.hpa.max }}
  targetCPUUtilizationPercentage: {{ .iiii.hpa.cpuPorcentage }}
---
  {{- else if .Values.iiii.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .iiii.name }}
  minReplicas: {{ .Values.iiii.hpa.min }}
  maxReplicas: {{ .Values.iiii.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.iiii.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}

