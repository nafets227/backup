{{/*
Common pod template for test-pod and CronJob
*/}}
{{- define "nafets227-backup.podSpec" -}}
restartPolicy: Never
automountServiceAccountToken: false
{{- with .Values.podSecurityContext }}
securityContext:
{{- toYamlPretty . | nindent 2 }}
{{- end }}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
{{- toYamlPretty . | nindent 2 }}
{{- end }}
containers:
  - name: {{ .Chart.Name }}
    image: {{ .Values.image.repository }}:{{
      .Values.image.tag | default .Chart.AppVersion }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    args:
      - "."
      - "/backup-script-onedrive"
    {{- with .Values.securityContext }}
    securityContext:
    {{- toYamlPretty . | nindent 6 }}
    {{- end }}
    {{- with .Values.resources }}
    resources:
    {{- toYamlPretty . | nindent 6 }}
    {{- end }}
    volumeMounts:
      - name: tmp
        mountPath: /tmp
    {{- with .Values.volumeMounts }}
    {{- toYamlPretty . | nindent 6 }}
    {{- end }}
volumes:
  - name: tmp
    emptyDir: {}
{{- with .Values.volumes }}
{{- toYamlPretty . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{- toYamlPretty . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{- toYamlPretty . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{- toYamlPretty . | nindent 2 }}
{{- end }}
{{- end }}
