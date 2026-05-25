# MemFlip Kubernetes Backup And Restore

This document defines the owned backup and restore contract for the `memflip-dev` Kubernetes slice.

## Scope

The current MemFlip Kubernetes backup and restore contract covers:

- PostgreSQL business data
  - `users`
  - `games`
  - `game_matches`
- Redis continuity state
  - primary Redis dataset used by the application

## Storage Model

Backups are stored on:

- PVC: `memflip-backup-storage`

Scheduled state backups are produced by:

- CronJob: `memflip-state-backup`

Default scheduled behavior:

- daily backup run at `0 5 * * *` in `Etc/UTC`
- keep the most recent `7` backup sets

Each backup run produces:

- `memflip-postgres-<timestamp>.dump`
- `memflip-redis-<timestamp>.rdb`

## Operator Commands

```bash
./scripts/k8s-backup-run.sh
./scripts/k8s-backup-inspect.sh
./scripts/k8s-backup-delete.sh --help
./scripts/k8s-restore-run.sh --help
./scripts/k8s-restore-verify.sh
```

## GitOps Control During Restore Drills

Suspend automation:

```bash
kubectl patch application internal-developer-platform-dev-root -n argocd --type json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
kubectl patch application memflip-dev -n argocd --type json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
```

Re-enable automation:

```bash
kubectl patch application internal-developer-platform-dev-root -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl patch application memflip-dev -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'
kubectl annotate application memflip-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Live Validation Notes

The MemFlip Phase 8 backup and restore path was validated live on `2026-05-25`.

Validated backup set:

- `memflip-postgres-20260525T043725Z.dump`
- `memflip-redis-20260525T043725Z.rdb`

Validated restore result:

- PostgreSQL tables restored:
  - `users`
  - `games`
  - `game_matches`
- PostgreSQL row counts after restore:
  - `users=9`
  - `games=5`
  - `game_matches=6`
- Redis primary PVC state restored:
  - `/redis-data/dump.rdb`
  - `/redis-data/appendonlydir/appendonly.aof.1.base.rdb`
  - `/redis-data/appendonlydir/appendonly.aof.1.incr.aof`
  - `/redis-data/appendonlydir/appendonly.aof.manifest`

## Issues Encountered And Fixes Applied

### 1. Verification helper env expansion

The first restore verification attempt failed because the helper manifest expanded shell variables too early while rendering the pod YAML.

Fix:

- escaped runtime environment references such as `\${PGHOST}` and `\${PGPORT}` in the helper command block

### 2. Verification helper command-substitution rendering

The next verification attempt failed because the unquoted heredoc expanded `$(seq 1 60)` locally before `kubectl apply`, which broke the generated YAML.

Fix:

- escaped command substitution inside the helper pod command block:
  - `\$(seq 1 60)`
