# Next Steps

## Current Intended Flow

The design is now:

1. Terraform renders `argocd_values`, `argocd_root_app`, the Ansible inventory, and the Ansible vars file.
2. Terraform always runs `ansible-playbook` locally through [`terraform/modules/bootstrap_ansible`](/home/khaleds/personal-projects/kube-signal/terraform/modules/bootstrap_ansible/main.tf:1).
3. Ansible always targets `localhost` through [`ansible/playbooks/bootstrap.yml`](/home/khaleds/personal-projects/kube-signal/ansible/playbooks/bootstrap.yml:1).
4. Ansible installs Argo CD first, then applies the root app.
5. Argo CD then syncs the GitOps applications.


## GitOps Problems To Fix After Bootstrap Works

Only do this after the local bootstrap path is working.

1. Fix the malformed root kustomization.
   [`gitops/argo-apps/overlays/default/root/kustomization.yaml`](/home/khaleds/personal-projects/kube-signal/gitops/argo-apps/overlays/default/root/kustomization.yaml:1) is invalid because `metallb.yaml` is indented under the previous list item.

2. Add the missing `AppProject` for `platform`.
   Several Argo CD `Application` manifests use `project: platform`, but there is no `AppProject` manifest for it in the repo.

3. Fix broken child application paths and references.
   Current examples:
   - [`gitops/argo-apps/base/external-dns.yaml`](/home/khaleds/personal-projects/kube-signal/gitops/argo-apps/base/external-dns.yaml:12) points to a path that does not exist
   - [`gitops/apps/kyverno/kustomization.yaml`](/home/khaleds/personal-projects/kube-signal/gitops/apps/kyverno/kustomization.yaml:11) references the wrong filename
   - [`gitops/apps/istio/istio-main/kustomization.yaml`](/home/khaleds/personal-projects/kube-signal/gitops/apps/istio/istio-main/kustomization.yaml:1) still needs a real Istio chart/repo layout

4. Normalize the Istio app-of-apps structure.
   There are still overlapping patterns between `gitops/argo-apps/base/istio-main.yaml` and the separate manifests under `gitops/argo-apps/base/istio/`.

5. Validate every GitOps path with `kustomize build` before relying on Argo CD sync.

## Enhancements After The Core Flow Is Stable

1. Add a validation workflow for `terraform fmt`, `terraform validate`, `ansible-playbook --syntax-check`, and `kustomize build`.
2. Commit and track the `ansible/` directory properly if it is intended to be part of the project.
3. Update the README so it reflects the real flow now: Terraform local -> Ansible localhost -> Argo CD bootstrap -> GitOps sync.
