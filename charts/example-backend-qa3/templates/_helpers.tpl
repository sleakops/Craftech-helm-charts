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
# kkk      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "kkk.resources" -}}
  {{- if .kkk.resources -}}
          resources:
{{ toYaml .kkk.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.kkk.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.kkk" -}}
{{- if .kkk.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .kkk.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
    spec:
      terminationGracePeriodSeconds: {{ .kkk.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .kkk.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.kkk.command }}
          command: {{- toYaml .Values.kkk.command | nindent 10 }}
          args: {{ .Values.kkk.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .kkk.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .kkk.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .kkk.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .kkk.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "kkk.resources" . }}
          {{- if .Values.kkk.envFrom }}
          envFrom:
          {{- toYaml .Values.kkk.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .kkk.extraEnvironmentVars -}}
          {{- range $key, $value := .kkk.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .kkk.nodeSelector }}
      nodeSelector:
        {{ toYaml .kkk.nodeSelector }}
    {{ else if .Values.kkk.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.kkk.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.kkk.hpa" -}}
  {{- if .kkk.enabled -}}
  {{- if .kkk.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
  minReplicas: {{ .kkk.hpa.min }}
  maxReplicas: {{ .kkk.hpa.max }}
  targetCPUUtilizationPercentage: {{ .kkk.hpa.cpuPorcentage }}
---
  {{- else if .Values.kkk.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .kkk.name }}
  minReplicas: {{ .Values.kkk.hpa.min }}
  maxReplicas: {{ .Values.kkk.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.kkk.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# aaa      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "aaa.resources" -}}
  {{- if .aaa.resources -}}
          resources:
{{ toYaml .aaa.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.aaa.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.aaa" -}}
{{- if .aaa.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .aaa.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
    spec:
      terminationGracePeriodSeconds: {{ .aaa.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .aaa.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.aaa.command }}
          command: {{- toYaml .Values.aaa.command | nindent 10 }}
          args: {{ .Values.aaa.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .aaa.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .aaa.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .aaa.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .aaa.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "aaa.resources" . }}
          {{- if .Values.aaa.envFrom }}
          envFrom:
          {{- toYaml .Values.aaa.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .aaa.extraEnvironmentVars -}}
          {{- range $key, $value := .aaa.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .aaa.nodeSelector }}
      nodeSelector:
        {{ toYaml .aaa.nodeSelector }}
    {{ else if .Values.aaa.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.aaa.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.aaa.hpa" -}}
  {{- if .aaa.enabled -}}
  {{- if .aaa.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
  minReplicas: {{ .aaa.hpa.min }}
  maxReplicas: {{ .aaa.hpa.max }}
  targetCPUUtilizationPercentage: {{ .aaa.hpa.cpuPorcentage }}
---
  {{- else if .Values.aaa.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .aaa.name }}
  minReplicas: {{ .Values.aaa.hpa.min }}
  maxReplicas: {{ .Values.aaa.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.aaa.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ccccc      
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "ccccc.resources" -}}
  {{- if .ccccc.resources -}}
          resources:
{{ toYaml .ccccc.resources | indent 12}}
  {{ else }}
          resources:
{{ toYaml .Values.ccccc.resources | indent 12}}
  {{- end -}}
{{- end -}}

{{- define "example-backend.ccccc" -}}
{{- if .ccccc.enabled -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .ccccc.replicas | default 0 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
  template:
    metadata:
      annotations:
        timestamp: "{{ .Values.global.timestamp }}"
      labels:
        app: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
    spec:
      terminationGracePeriodSeconds: {{ .ccccc.terminationGracePeriodSeconds | default 300 }}
      containers:
        - name: {{ .ccccc.config.containerName | default "celery" }}
          image: {{ .Values.global.image.repository }}:{{ .Values.global.image.tag }}
          imagePullPolicy: {{ .Values.global.image.pullPolicy }}
          {{- if .Values.ccccc.command }}
          command: {{- toYaml .Values.ccccc.command | nindent 10 }}
          args: {{ .Values.ccccc.args }}
          {{- end }}
          {{- if .Values.api.readinessProbe.enabled }}
          readinessProbe:
            exec:
              command:
              - "/bin/sh"
              - "-c"
              - {{ .ccccc.readinessProbe.command | quote }}
            initialDelaySeconds: {{ .ccccc.readinessProbe.initialDelaySeconds }}
            timeoutSeconds: {{ .ccccc.readinessProbe.timeoutSeconds }}
            periodSeconds: {{ .ccccc.readinessProbe.periodSeconds }}
          {{- end }}
          {{ template "ccccc.resources" . }}
          {{- if .Values.ccccc.envFrom }}
          envFrom:
          {{- toYaml .Values.ccccc.envFrom | nindent 10 }}
          {{- end }}
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name

          {{- if .ccccc.extraEnvironmentVars -}}
          {{- range $key, $value := .ccccc.extraEnvironmentVars }}
          - name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
            value: {{ $value | quote }}
          {{- end -}}
          {{- end -}}
    {{ if .ccccc.nodeSelector }}
      nodeSelector:
        {{ toYaml .ccccc.nodeSelector }}
    {{ else if .Values.ccccc.nodeSelector }}
      nodeSelector:
        {{ toYaml .Values.ccccc.nodeSelector  }}
    {{ else -}}
    {{- end }}
---
{{- end -}}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "example-backend.ccccc.hpa" -}}
  {{- if .ccccc.enabled -}}
  {{- if .ccccc.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
  namespace: {{ .Values.global.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
  minReplicas: {{ .ccccc.hpa.min }}
  maxReplicas: {{ .ccccc.hpa.max }}
  targetCPUUtilizationPercentage: {{ .ccccc.hpa.cpuPorcentage }}
---
  {{- else if .Values.ccccc.hpa -}}
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ template "example-backend.fullname" . }}-celery-api-{{ .ccccc.name }}
  minReplicas: {{ .Values.ccccc.hpa.min }}
  maxReplicas: {{ .Values.ccccc.hpa.max }}
  targetCPUUtilizationPercentage: {{ .Values.ccccc.hpa.cpuPorcentage }}
---
  {{ else }}
  {{ end }}
  {{ end }}
{{- end -}}

