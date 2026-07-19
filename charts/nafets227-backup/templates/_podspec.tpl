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
    env:
      {{- with .Values.nafets227Backup.mailAlert }}
      {{- if .enabled }}
      - name: MAIL_TO
        value: {{ .to | quote }}
      - name: MAIL_FROM
        value: {{ .from | quote }}
      {{- with .smtp }}
      - name: MAIL_SERVER
        value: {{ .host | quote }}
      - name: MAIL_PORT
        value: {{ .port | quote }}
      - name: MAIL_HOSTNAME
        value: {{ .hostname | quote }}
      {{- with .auth }}
      {{- if .existingSecret }}
      - name: MAIL_USER
        valueFrom:
          secretKeyRef:
            name: {{ .existingSecret }}
            key: {{ .usernameKey }}
      - name: MAIL_PW
        value: "/secrets/mailAuth/{{ .passwordKey }}"
      {{- end }}
      {{- end }}
      - name: MAIL_SSL
        value: {{ if eq .encryption "starttls" }}"1"{{- else }}"0"{{- end }}
      {{- end }}
      {{- end }}
      {{- end }}
      - name: DRY_RUN
        value: {{ .dryRun | quote }}
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
    {{- with .Values.nafets227Backup.mailAlert }}
    {{- if .enabled }}
    {{- with .smtp.auth }}
    {{- if .existingSecret }}
      - name: auth
        mountPath: /secrets/mailAuth
    {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
volumes:
  - name: tmp
    emptyDir: {}
{{- with .Values.volumes }}
{{- toYamlPretty . | nindent 2 }}
{{- end }}
  # jscpd:ignore-start
{{- with .Values.nafets227Backup.mailAlert }}
{{- if .enabled }}
{{- with .smtp.auth }}
{{- if .existingSecret }}
  - name: auth
    secret:
      secretName: {{ .existingSecret }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
  # jscpd:ignore-end
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
