{{/*
Copyright VMware, Inc.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "solr.zookeeper.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "zookeeper" "chartValues" .Values.zookeeper "context" $) -}}
{{- end -}}

{{/*
Return the proper Apache Solr image name
*/}}
{{- define "solr.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) -}}
{{- end -}}

{{/*
Return the proper image name (for the init container volume-permissions image)
*/}}
{{- define "solr.volumePermissions.image" -}}
{{- include "common.images.image" ( dict "imageRoot" .Values.volumePermissions.image "global" .Values.global ) -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "solr.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.volumePermissions.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Check if there are rolling tags in the images
*/}}
{{- define "solr.checkRollingTags" -}}
{{- include "common.warnings.rollingTag" .Values.image }}
{{- include "common.warnings.rollingTag" .Values.volumePermissions.image }}
{{- end -}}

{{/*
 Create the name of the service account to use
 */}}
{{- define "solr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default (include "common.names.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
    {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Return the Solr authentication credentials secret
*/}}
{{- define "solr.secretName" -}}
{{- coalesce (tpl .Values.auth.existingSecret $) (include "common.names.fullname" .) -}}
{{- end -}}

{{/*
Get the password key to be retrieved from the Solr auth secret.
*/}}
{{- define "solr.secretPasswordKey" -}}
{{- if and .Values.auth.existingSecret .Values.auth.existingSecretPasswordKey -}}
{{- printf "%s" .Values.auth.existingSecretPasswordKey -}}
{{- else -}}
{{- printf "solr-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a Solr authentication credentials secret object should be created
*/}}
{{- define "solr.createSecret" -}}
{{- if and .Values.auth.enabled (empty .Values.auth.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Returns the available value for certain key in an existing secret (if it exists),
otherwise it generates a random value.
*/}}
{{- define "getValueFromSecret" }}
    {{- $len := (default 16 .Length) | int -}}
    {{- $obj := (lookup "v1" "Secret" .Namespace .Name).data -}}
    {{- if $obj }}
        {{- index $obj .Key | b64dec -}}
    {{- else -}}
        {{- randAlphaNum $len -}}
    {{- end -}}
{{- end }}

{{/*
Return Solr admin password
*/}}
{{- define "solr.password" -}}
{{- if not (empty .Values.auth.adminPassword) -}}
    {{- .Values.auth.adminPassword -}}
{{- else -}}
    {{- include "getValueFromSecret" (dict "Namespace" (include "common.names.namespace" .) "Name" (include "common.names.fullname" .) "Length" 10 "Key" "solr-password")  -}}
{{- end -}}
{{- end -}}

{{/*
Return proper Zookeeper hosts
*/}}
{{- define "solr.zookeeper.hosts" -}}
{{- if .Values.externalZookeeper.servers -}}
    {{- include "common.tplvalues.render" (dict "value" (join "," .Values.externalZookeeper.servers) "context" $) -}}
{{- else -}}
    {{- $zookeeperList := list -}}
    {{- $releaseNamespace :=  default (include "common.names.namespace" .) .Values.zookeeper.namespaceOverride -}}
    {{- $clusterDomain := .Values.clusterDomain -}}
    {{- $zookeeperFullname := include "solr.zookeeper.fullname" . -}}
    {{- range $e, $i := until (int .Values.zookeeper.replicaCount) -}}
        {{- $zookeeperList = append $zookeeperList (printf "%s-%d.%s-headless.%s.svc.%s:%d" $zookeeperFullname $i $zookeeperFullname $releaseNamespace $clusterDomain (int $.Values.zookeeper.containerPorts.client))  -}}
    {{- end -}}
    {{- include "common.tplvalues.render" (dict "value" (join "," $zookeeperList) "context" $) -}}
{{- end -}}
{{- end -}}

{{/*
Return proper Zookeeper hosts
*/}}
{{- define "solr.zookeeper.port" -}}
{{- if .Values.externalZookeeper.servers -}}
    {{- include "solr.zookeeper.hosts" . | regexFind ":[0-9]+" | trimPrefix ":" | default "2181" | int -}}
{{- else if .Values.zookeeper.enabled -}}
    {{- int .Values.zookeeper.containerPorts.client -}}
{{- else -}}
    {{- int "2181" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a TLS secret object should be created
*/}}
{{- define "solr.createTlsSecret" -}}
{{- if and .Values.tls.enabled .Values.tls.autoGenerated (not .Values.tls.certificatesSecretName) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the Solr TLS credentials secret
*/}}
{{- define "solr.tlsSecretName" -}}
{{- $secretName := .Values.tls.certificatesSecretName -}}
{{- if $secretName -}}
    {{- printf "%s" (tpl $secretName $) -}}
{{- else -}}
    {{- printf "%s-crt" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret containing the Keystore and Truststore password should be created for Solr client
*/}}
{{- define "solr.createTlsPasswordsSecret" -}}
{{- if and .Values.tls.enabled (not .Values.tls.passwordsSecretName) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a TLS credentials secret object should be created
*/}}
{{- define "solr.tlsPasswordsSecret" -}}
{{- $secretName := .Values.tls.passwordsSecretName -}}
{{- if $secretName -}}
    {{- printf "%s" (tpl $secretName $) -}}
{{- else -}}
    {{- printf "%s-tls-pass" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message.
*/}}
{{- define "solr.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "solr.validateValues.tls" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/*
Validate values of Solr - TLS enabled
*/}}
{{- define "solr.validateValues.tls" -}}
{{- if and .Values.tls.enabled (not .Values.tls.autoGenerated) (not .Values.tls.certificatesSecretName) }}
solr: tls.enabled
    In order to enable TLS, you also need to provide
    an existing secret containing the Keystore and Truststore or
    enable auto-generated certificates.
{{- end -}}
{{- end -}}
