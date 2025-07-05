apiVersion: apps/v1
kind: Deployment
metadata:
  name: "{{ include "apitwo.fullname" . }}-openresty"
  labels:
    {{- include "apitwo.labels" . | nindent 4 }}
  # 当 ConfigMap 发生变更时自动滚动更新 Pod
  # Trigger rolling update when ConfigMap changes
  annotations:
    checksum/config: {{ include (print $.Template.BasePath "/openresty-configmap.yaml.tpl") . | sha256sum }}
spec:
  replicas: {{ .Values.openresty.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "apitwo.name" . }}
      app.kubernetes.io/component: openresty
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "apitwo.name" . }}
        app.kubernetes.io/component: openresty
      # 当 ConfigMap 发生变更时自动滚动更新 Pod
      # Trigger rolling update when ConfigMap changes
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/openresty-configmap.yaml.tpl") . | sha256sum }}
    spec:
      containers:
        - name: openresty
          image: {{ .Values.openresty.image }}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: {{ .Values.openresty.port }}
          volumeMounts:
            - name: openresty-conf
              mountPath: /usr/local/openresty/nginx/conf/nginx.conf
              subPath: nginx.conf
            - name: openresty-conf
              mountPath: /usr/local/openresty/nginx/lua/limit.lua
              subPath: limit.lua
          env:
            - name: REDIS_HOST
              value: {{ .Values.redis.host | quote }}
            - name: REDIS_PORT
              value: {{ .Values.redis.port | quote }}
          resources:
{{- toYaml .Values.openresty.resources | indent 12 }}
      volumes:
        - name: openresty-conf
          configMap:
            name: "{{ include "apitwo.fullname" . }}-openresty-conf" 