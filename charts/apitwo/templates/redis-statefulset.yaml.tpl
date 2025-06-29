apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  labels:
    {{- include "apitwo.labels" . | nindent 4 }}
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "apitwo.name" . }}
      app.kubernetes.io/component: redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "apitwo.name" . }}
        app.kubernetes.io/component: redis
    spec:
      containers:
        - name: redis
          image: {{ .Values.redis.image }}
          ports:
            - containerPort: {{ .Values.redis.port }}
          volumeMounts:
            - name: redis-data
              mountPath: /data
  {{- if .Values.redis.persistence.enabled }}
  volumeClaimTemplates:
    - metadata:
        name: redis-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.redis.persistence.size }}
        {{- if .Values.redis.persistence.storageClass }}
        storageClassName: {{ .Values.redis.persistence.storageClass }}
        {{- end }}
  {{- else }}
  template:
    spec:
      volumes:
        - name: redis-data
          emptyDir: {}
  {{- end }} 