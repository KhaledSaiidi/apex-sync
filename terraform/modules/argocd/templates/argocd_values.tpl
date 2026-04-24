server:
  service:
    type: ${argocd_server_service_type}
    annotations: {}

configs:
  cm:
%{ if argocd_reconciliation_timeout != "" ~}
    timeout.reconciliation: "${argocd_reconciliation_timeout}"
%{ endif ~}

  params:
    server.insecure: "true"
    controller.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"
    server.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"

extraObjects:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-lovely-plugin-config
      namespace: ${argocd_namespace}
    data:
      plugin.yaml: |
        apiVersion: argoproj.io/v1alpha1
        kind: ConfigManagementPlugin
        metadata:
          name: ${argocd_lovely_plugin_name}
        spec:
          generate:
            command:
              - /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name}
              - generate

repoServer:
  initContainers:
    - name: install-${argocd_lovely_plugin_k8s_name}
      image: "${argocd_lovely_plugin_image}"
      imagePullPolicy: IfNotPresent
      command:
        - /bin/sh
        - -c
      args:
        - |
          cp /usr/local/bin/argocd-lovely-plugin /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name}
          chmod 0555 /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name}
      volumeMounts:
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins

  extraContainers:
    - name: lovely-plugin
      image: "${argocd_lovely_plugin_image}"
      imagePullPolicy: IfNotPresent
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
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
        - name: lovely-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: plugin.yaml
        - name: cmp-tmp
          mountPath: /tmp

  volumes:
    - name: lovely-plugin-config
      configMap:
        name: argocd-lovely-plugin-config
    - name: cmp-tmp
      emptyDir: {}
