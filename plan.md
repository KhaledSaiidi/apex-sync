# Stateful Resources Plan

~~- Install the Percona operator as its own GitOps unit first, keep the MySQL cluster CR separate from the operator bundle so upgrades and troubleshooting stay clean, and run the operator in cluster-wide mode from its dedicated namespace.~~

~~- Standardize on `HAProxy` first and keep `ProxySQL` disabled unless you later need query routing, read/write split rules, or connection multiplexing.~~

~~- Make the cluster truly HA: keep `pxc.size: 3`, `haproxy.size: 3`, use the intended `StorageClass`, add explicit limits/probes/security context, and keep anti-affinity / topology spreading / PDBs enabled.~~

~~- Replace placeholder and commented defaults with a real production spec: fixed storage class, resource requests and limits, TLS on, pinned image versions, and only the features you actually use.~~

~~- Decide the secret flow before exposing the database: do not commit DB passwords in Git; use generated secrets via the operator plus a GitOps-safe secret source for backup credentials.~~

~~- Expose one stable internal write endpoint first through HAProxy with a clear service name, then add a separate read-only endpoint only if applications actually need it.~~

~~- Install gaqrage to have an S3 like bucket in the cluster to persist the backups and create aws_access_key_id, aws_secret_access_key, endpointUrl, bucket_name and region for it so it can be used by the backup in stateful-resources~~

- Configure backups to object storage S3 like bucket: one daily full backup, retention policy, and restore-target naming that is easy to operate.

- Enable PITR with binlog uploads to the same object storage so you can restore between daily full backups. For binlogs, Percona recommends: at least a separate folder/prefix for each cluster


- Add a restore test path early: document and test full restore and point-in-time restore before calling the database production ready.

- Add observability last: metrics, alerts, and backup failure visibility, then remove leftover commented examples so the manifest reflects the real supported design.
