apiVersion: v1
kind: ConfigMap
metadata:
  name: "{{ include "apitwo.fullname" . }}-openresty-conf"
  labels:
    {{- include "apitwo.labels" . | nindent 4 }}
data:
  nginx.conf: |-
{{ (.Files.Get "files/nginx.conf") | indent 4 }}
  limit.lua: |-
{{ (.Files.Get "files/limit.lua") | indent 4 }} 