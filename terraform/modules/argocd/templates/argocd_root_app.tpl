apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${gitops_root_app_name}
  namespace: ${argocd_namespace}
  labels:
    app.kubernetes.io/managed-by: terraform
    app.kubernetes.io/part-of: gitops-bootstrap
spec:
  project: ${gitops_root_app_project}
  source:
    repoURL: ${gitops_root_app_repo_url}
    targetRevision: ${gitops_root_app_target_revision}
    path: ${gitops_root_app_path}
    plugin:
      name: envsubstappofapp
      env:
        - name: metallb_config_addresses_start
          value: "${metallb_addresses_start}"
        - name: metallb_config_addresses_end
          value: "${metallb_addresses_end}"
        - name: gitops_root_app_repo_url
          value: "${gitops_root_app_repo_url}"
        - name: gitops_root_app_target_revision
          value: "${gitops_root_app_target_revision}"
        - name: cert_manager_acme_email
          value: "${cert_manager_acme_email}"
        - name: cert_manager_route53_region
          value: "${cert_manager_route53_region}"
        - name: cert_manager_route53_hosted_zone_id
          value: "${cert_manager_route53_hosted_zone_id}"
        - name: base_domain
          value: "${base_domain}"
        - name: cert_manager_version
          value: "${cert_manager_version}"
        - name: external_dns_version
          value: "${external_dns_version}"
        - name: external_dns_txt_owner_id
          value: "${external_dns_txt_owner_id}"
        - name: istio_main_version
          value: "${istio_main_version}"
        - name: gateway_api_version
          value: "${gateway_api_version}"
        - name: kiali_version
          value: "${kiali_version}"
        - name: kyverno_version
          value: "${kyverno_version}"
        - name: metallb_version
          value: "${metallb_version}"
        - name: openebs_version
          value: "${openebs_version}"
        - name: reflector_version
          value: "${reflector_version}"
        - name: percona_version
          value: "${percona_version}"
        - name: garage_version
          value: "${garage_version}"
        - name: kyverno_admission_controller_replicas
          value: "${kyverno_admission_controller_replicas}"
        - name: kyverno_background_controller_replicas
          value: "${kyverno_background_controller_replicas}"
        - name: kyverno_cleanup_controller_replicas
          value: "${kyverno_cleanup_controller_replicas}"
        - name: kyverno_reports_controller_replicas
          value: "${kyverno_reports_controller_replicas}"
        - name: reflector_min_replicas
          value: "${reflector_min_replicas}"
        - name: reflector_max_replicas
          value: "${reflector_max_replicas}"
        - name: stateful_operator_replicas
          value: "${stateful_operator_replicas}"
        - name: garage_replication_factor
          value: "${garage_replication_factor}"
        - name: garage_replicas
          value: "${garage_replicas}"
        - name: istiod_replicas
          value: "${istiod_replicas}"
        - name: openebs_localpv_replicas
          value: "${openebs_localpv_replicas}"
        - name: public_gateway_replicas
          value: "${public_gateway_replicas}"
        - name: public_gateway_min_replicas
          value: "${public_gateway_min_replicas}"
        - name: public_gateway_max_replicas
          value: "${public_gateway_max_replicas}"
        - name: cert_manager_replicas
          value: "${cert_manager_replicas}"
        - name: cert_manager_webhook_replicas
          value: "${cert_manager_webhook_replicas}"
        - name: cert_manager_cainjector_replicas
          value: "${cert_manager_cainjector_replicas}"
        - name: kiali_replicas
          value: "${kiali_replicas}"
        - name: stateful_resources_pxc_replicas
          value: "${stateful_resources_pxc_replicas}"
        - name: stateful_resources_haproxy_replicas
          value: "${stateful_resources_haproxy_replicas}"
%{ for name, value in resource_env ~}
        - name: ${name}
          value: "${value}"
%{ endfor ~}
  destination:
    server: ${gitops_root_app_destination_server}
    namespace: ${gitops_root_app_destination_namespace}
  ignoreDifferences:
    - group: argoproj.io
      kind: Application
      name: kyverno
      jsonPointers:
        - /metadata/finalizers
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
