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

repoServer:
  extraContainers:
    - name: cmp-envsubstappofapp
      image: ${argocd_cmp_image}
      imagePullPolicy: IfNotPresent
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
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
        - name: cmp-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: envsubstappofapp.yaml
        - name: cmp-tmp
          mountPath: /tmp
    - name: cmp-envsubst
      image: ${argocd_cmp_image}
      imagePullPolicy: IfNotPresent
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
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
        - name: cmp-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: envsubst.yaml
        - name: cmp-tmp
          mountPath: /tmp

  volumes:
    - name: cmp-plugin-config
      configMap:
        name: argocd-cmp-cm
    - name: cmp-tmp
      emptyDir: {}
