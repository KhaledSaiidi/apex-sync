server:
  service:
    type: ${argocd_server_service_type}
    annotations: {}

configs:
  cm:
%{ if argocd_reconciliation_timeout != "" ~}
    timeout.reconciliation: "${argocd_reconciliation_timeout}"
%{ endif ~}
    resource.customizations.health.argoproj.io_Application: |
      hs = {}
      hs.status = "Progressing"
      hs.message = ""
      if obj.status ~= nil then
        if obj.status.health ~= nil then
          hs.status = obj.status.health.status
          if obj.status.health.message ~= nil then
            hs.message = obj.status.health.message
          end
        end
        if obj.status.operationState ~= nil and obj.status.operationState.phase ~= nil then
          if obj.status.operationState.phase == "Error" or obj.status.operationState.phase == "Failed" then
            hs.status = "Degraded"
            if obj.status.operationState.message ~= nil then
              hs.message = obj.status.operationState.message
            end
          elseif hs.status == "Healthy" and (obj.status.operationState.phase == "Running" or obj.status.operationState.phase == "Terminating") then
            hs.status = "Progressing"
            if obj.status.operationState.message ~= nil then
              hs.message = obj.status.operationState.message
            end
          end
        end
        if hs.status == "Healthy" and obj.status.sync ~= nil and obj.status.sync.status ~= nil and obj.status.sync.status ~= "Synced" then
          hs.status = "Progressing"
          hs.message = "Sync status: " .. obj.status.sync.status
        end
      end
      return hs

  params:
    server.insecure: "true"
    controller.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"
    server.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"

  cmp:
    create: true
    plugins:
      envsubstappofapp.yaml: |
        apiVersion: argoproj.io/v1alpha1
        kind: ConfigManagementPlugin
        metadata:
          name: envsubstappofapp
        spec:
          allowConcurrency: true
          generate:
            command:
              - /home/argocd/cmp-server/scripts/envsubstappofapp.sh
      envsubst.yaml: |
        apiVersion: argoproj.io/v1alpha1
        kind: ConfigManagementPlugin
        metadata:
          name: envsubst
        spec:
          allowConcurrency: true
          generate:
            command:
              - /home/argocd/cmp-server/scripts/envsubst.sh

extraObjects:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-envsubst-plugin-scripts
      namespace: ${argocd_namespace}
    data:
      envsubstappofapp.sh: |
        #!/bin/sh
        set -eu

        kustomize build . | envsubst
      envsubst.sh: |
        #!/bin/sh
        set -eu

        workdir="$(mktemp -d)"
        cleanup() {
          rm -rf "$workdir"
        }
        trap cleanup EXIT

        src="$workdir/src"
        mkdir -p "$src"
        cp -R ./. "$src"
        cd "$src"

        find . -type f \( -name '*.yaml' -o -name '*.yml' \) | while IFS= read -r file; do
          tmp="$file.tmp"
          envsubst <"$file" >"$tmp"
          mv "$tmp" "$file"
        done

        kustomize build --enable-helm .

repoServer:
  initContainers:
    - name: install-envsubst-for-cmp
      image: '{{ default .Values.global.image.repository .Values.repoServer.image.repository }}:{{ .Values.repoServer.image.tag | default (.Values.global.image.tag | default .Chart.AppVersion) }}'
      imagePullPolicy: IfNotPresent
      securityContext:
        runAsNonRoot: false
        runAsUser: 0
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
      command:
        - /bin/sh
        - -ec
      args:
        - |
          apt-get update
          apt-get install --no-install-recommends -y gettext-base
          cp /usr/bin/envsubst /custom-tools/envsubst
          chmod 0555 /custom-tools/envsubst
          apt-get clean
          rm -rf /var/lib/apt/lists/*
      volumeMounts:
        - name: envsubst-tools
          mountPath: /custom-tools

  extraContainers:
    - name: cmp-envsubstappofapp
      image: '{{ default .Values.global.image.repository .Values.repoServer.image.repository }}:{{ .Values.repoServer.image.tag | default (.Values.global.image.tag | default .Chart.AppVersion) }}'
      imagePullPolicy: IfNotPresent
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
        - name: PATH
          value: /custom-tools:/usr/local/bin:/usr/bin:/bin
        - name: HOME
          value: /tmp
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: var-files
          mountPath: /var/run/argocd
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins
        - name: envsubst-tools
          mountPath: /custom-tools
          readOnly: true
        - name: envsubst-plugin-scripts
          mountPath: /home/argocd/cmp-server/scripts
          readOnly: true
        - name: cmp-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: envsubstappofapp.yaml
        - name: cmp-tmp
          mountPath: /tmp
    - name: cmp-envsubst
      image: '{{ default .Values.global.image.repository .Values.repoServer.image.repository }}:{{ .Values.repoServer.image.tag | default (.Values.global.image.tag | default .Chart.AppVersion) }}'
      imagePullPolicy: IfNotPresent
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
        - name: PATH
          value: /custom-tools:/usr/local/bin:/usr/bin:/bin
        - name: HOME
          value: /tmp
        - name: HELM_CACHE_HOME
          value: /tmp/helm/cache
        - name: HELM_CONFIG_HOME
          value: /tmp/helm/config
        - name: HELM_DATA_HOME
          value: /tmp/helm/data
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: var-files
          mountPath: /var/run/argocd
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins
        - name: envsubst-tools
          mountPath: /custom-tools
          readOnly: true
        - name: envsubst-plugin-scripts
          mountPath: /home/argocd/cmp-server/scripts
          readOnly: true
        - name: cmp-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: envsubst.yaml
        - name: cmp-tmp
          mountPath: /tmp

  volumes:
    - name: cmp-plugin-config
      configMap:
        name: argocd-cmp-cm
    - name: envsubst-plugin-scripts
      configMap:
        name: argocd-envsubst-plugin-scripts
        defaultMode: 0555
    - name: envsubst-tools
      emptyDir: {}
    - name: cmp-tmp
      emptyDir: {}
