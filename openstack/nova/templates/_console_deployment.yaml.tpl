{{- define "nova.console_deployment" }}
{{- $name := index . 1 }}
{{- $config := index . 2 }}
{{- with index . 0 }}
kind: Deployment
apiVersion: extensions/v1beta1

metadata:
  name: nova-console-{{ $name }}
  labels:
    system: openstack
    type: backend
    component: nova
spec:
  replicas: {{ .Values.pod.replicas.console }}
  revisionHistoryLimit: {{ .Values.pod.lifecycle.upgrades.deployments.revision_history }}
  strategy:
    type: {{ .Values.pod.lifecycle.upgrades.deployments.podReplacementStrategy }}
    {{ if eq .Values.pod.lifecycle.upgrades.deployments.podReplacementStrategy "RollingUpdate" }}
    rollingUpdate:
      maxUnavailable: {{ .Values.pod.lifecycle.upgrades.deployments.rollingUpdate.maxUnavailable }}
      maxSurge: {{ .Values.pod.lifecycle.upgrades.deployments.rollingUpdate.maxSurge }}
    {{ end }}
  selector:
    matchLabels:
      name: nova-console-{{ $name }}
  template:
    metadata:
      labels:
        name: nova-console-{{ $name }}
{{ tuple . "nova" (print "console-" $name) | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
      annotations:
        configmap-etc-hash: {{ include (print .Template.BasePath "/etc-configmap.yaml") . | sha256sum }}
    spec:
{{ tuple . "nova" (print "console-" $name) | include "kubernetes_pod_anti_affinity" | indent 6 }}
      hostname: nova-console-{{ $name }}
      volumes:
      - name: etcnova
        emptyDir: {}
      - name: nova-etc
        configMap:
          name: nova-etc
      containers:
      - name: nova-console-{{ $name }}
        image: {{ .Values.global.imageRegistry}}/{{.Values.global.image_namespace}}/ubuntu-source-nova-{{ $name }}proxy:{{index .Values (print "imageVersionNova" (title $name) "proxy") | default .Values.imageVersion | required "Please set nova.imageVersion or similar" }}
        imagePullPolicy: IfNotPresent
        command:
        - dumb-init
        - kubernetes-entrypoint
        env:
        - name: COMMAND
          value: nova-{{ $name }}proxy
        - name: NAMESPACE
          value: {{ .Release.Namespace }}
        - name: LANG
          value: en_US.UTF-8
{{- if .Values.python_warnings }}
        - name: PYTHONWARNINGS
          value: {{ .Values.python_warnings | quote }}
{{- end }}
        ports:
        - name: {{ $name }}
          containerPort: {{ index .Values.consoles $name "portInternal" }}
        volumeMounts:
        - name: etcnova
          mountPath: /etc/nova
        - name: nova-etc
          mountPath: /etc/nova/nova.conf
          subPath: nova.conf
          readOnly: true
        - name: nova-etc
          mountPath: /etc/nova/logging.ini
          subPath: logging.ini
          readOnly: true
{{- end }}
{{- end }}