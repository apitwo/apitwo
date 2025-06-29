apiVersion: v1
kind: Service
metadata:
  name: "{{ include \"apitwo.fullname\" . }}-openresty"
  labels:
    {{- include "apitwo.labels" . | nindent 4 }}
spec:
  type: {{ .Values.openresty.service.type }}
  ports:
    - port: {{ .Values.openresty.port }}
      targetPort: {{ .Values.openresty.port }}
  selector:
    app.kubernetes.io/name: {{ include "apitwo.name" . }}
    app.kubernetes.io/component: openresty 