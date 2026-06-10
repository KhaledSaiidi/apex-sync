#!/bin/sh
set -eu

chown_requests_cpu="${OPENEBS_HOSTPATH_CHOWN_REQUESTS_CPU:?missing OPENEBS_HOSTPATH_CHOWN_REQUESTS_CPU}"
chown_requests_memory="${OPENEBS_HOSTPATH_CHOWN_REQUESTS_MEMORY:?missing OPENEBS_HOSTPATH_CHOWN_REQUESTS_MEMORY}"
chown_limits_cpu="${OPENEBS_HOSTPATH_CHOWN_LIMITS_CPU:?missing OPENEBS_HOSTPATH_CHOWN_LIMITS_CPU}"
chown_limits_memory="${OPENEBS_HOSTPATH_CHOWN_LIMITS_MEMORY:?missing OPENEBS_HOSTPATH_CHOWN_LIMITS_MEMORY}"

kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers | while IFS= read -r node; do
  [ -n "$node" ] || continue

  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: openebs-hostpath-setup-$node
  namespace: openebs
  labels:
    app: openebs-hostpath-setup
spec:
  template:
    spec:
      restartPolicy: OnFailure
      nodeName: $node
      tolerations:
        - operator: Exists
      containers:
        - name: hostpath-setup
          image: docker.io/library/busybox:1.36.1
          resources:
            requests:
              cpu: "$chown_requests_cpu"
              memory: "$chown_requests_memory"
            limits:
              cpu: "$chown_limits_cpu"
              memory: "$chown_limits_memory"
          command:
            - sh
            - -c
            - |
              mkdir -p /host/var/openebs/apex-sync
              chmod 0777 /host/var/openebs/apex-sync
          securityContext:
            runAsUser: 0
          volumeMounts:
            - name: host-root
              mountPath: /host
      volumes:
        - name: host-root
          hostPath:
            path: /
            type: Directory
EOF
done

kubectl wait --for=condition=complete job -l app=openebs-hostpath-setup -n openebs --timeout=1200s
kubectl delete job -n openebs -l app=openebs-hostpath-setup --ignore-not-found=true
