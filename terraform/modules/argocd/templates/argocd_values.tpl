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
