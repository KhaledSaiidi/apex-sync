# Next Steps

## Current Intended Flow

The design is now:

1. Terraform renders `argocd_values`, `argocd_root_app`, the Ansible inventory, and the Ansible vars file.
2. Terraform always runs `ansible-playbook` locally through [`terraform/modules/bootstrap_ansible`](/home/khaleds/personal-projects/kube-signal/terraform/modules/bootstrap_ansible/main.tf:1).
3. Ansible always targets `localhost` through [`ansible/playbooks/bootstrap.yml`](/home/khaleds/personal-projects/kube-signal/ansible/playbooks/bootstrap.yml:1).
4. Ansible installs Argo CD first, then applies the root app.
5. Argo CD then syncs the GitOps applications.

## Issues To Fix First

Fix these in this exact order.

1. Fix kubeconfig handling for the local-only bootstrap.
   Right now the playbook reads `cluster.kubeconfig.local_path`, but the Argo CD role still defaults to `kubeconfig_remote_path` in [`ansible/roles/argocd/defaults/main.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/argocd/defaults/main.yml:1). In local-only mode, Ansible should use the local kubeconfig path directly, or explicitly copy it first.

2. Define `argocd_release_name`.
   [`ansible/roles/argocd/tasks/install.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/argocd/tasks/install.yml:32) uses `argocd_release_name`, but it is not defined in the role defaults.

3. Decide the tooling contract for `kubectl` and `helm`.
   The playbook validates versions in [`ansible/playbooks/bootstrap.yml`](/home/khaleds/personal-projects/kube-signal/ansible/playbooks/bootstrap.yml:37), but it does not install either tool. Pick one model and make it explicit:
   - install them in Ansible
   - or document them as required local prerequisites

4. Fix the Argo CD readiness check for `argocd-application-controller`.
   [`ansible/roles/argocd/tasks/install.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/argocd/tasks/install.yml:76) waits for it as a Deployment, which is likely wrong for the Helm chart layout.

5. Add or remove the `kubernetes.core` dependency cleanly.
   [`ansible/roles/gitops_root_app/tasks/main.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/gitops_root_app/tasks/main.yml:40) uses `kubernetes.core.k8s_info`, but the repo does not define collection requirements yet.

6. Validate that the Terraform stack can actually complete a full local bootstrap.
   After the points above, run:
   - `terraform init`
   - `terraform apply`
   - `ansible-playbook --syntax-check`

## Inconsistencies To Clean Up Next

Do these after the first successful local bootstrap works.

1. Remove stale Terraform variables that still reflect the old remote/bastion model.
   [`terraform/stack/main/variables.tf`](/home/khaleds/personal-projects/kube-signal/terraform/stack/main/variables.tf:10) still keeps `remote_deployment`, and the same file still has `public_ip` and `ssh_path` even though the stack is now local-only.

2. Remove stale bastion wording from Ansible.
   The execution model is now local-only, but task names still say things like “Copy rendered Argo CD values to bastion” in [`ansible/roles/argocd/tasks/install.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/argocd/tasks/install.yml:21) and “Copy rendered root app manifest to bastion” in [`ansible/roles/gitops_root_app/tasks/main.yml`](/home/khaleds/personal-projects/kube-signal/ansible/roles/gitops_root_app/tasks/main.yml:22).

3. Simplify the local-only variable contract.
   The vars file still carries `cluster.ssh_private_key.local_path` even though local bootstrap does not use SSH anymore. Either keep it as an always-empty compatibility field or remove it from the playbook contract.

4. Add useful Terraform outputs.
   [`terraform/stack/main/outputs.tf`](/home/khaleds/personal-projects/kube-signal/terraform/stack/main/outputs.tf:1) is still empty. Expose at least:
   - inventory path
   - ansible vars path
   - Argo CD values path
   - root app path

5. Declare required providers explicitly.
   [`terraform/stack/main/provider.tf`](/home/khaleds/personal-projects/kube-signal/terraform/stack/main/provider.tf:1) still has an empty `required_providers` block.

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
