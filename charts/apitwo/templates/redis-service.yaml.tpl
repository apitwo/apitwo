apiVersion: v1
kind: Service
metadata:
  name: redis
  labels:
    {{- include "apitwo.labels" . | nindent 4 }}
spec:
  ports:
    - port: {{ .Values.redis.port }}
      targetPort: {{ .Values.redis.port }}
  selector:
    app.kubernetes.io/name: {{ include "apitwo.name" . }}
    app.kubernetes.io/component: redis 