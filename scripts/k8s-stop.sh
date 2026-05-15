#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="memflip-dev"
DEPLOYMENTS=(
  memflip-backend
  memflip-frontend
)
STATEFULSETS=(
  memflip-postgres
  memflip-redis
)

usage() {
  cat <<'EOF'
Usage: ./scripts/k8s-stop.sh [options]

Stop the MemFlip dev overlay from the current Kubernetes context.
This preserves the namespace and persistent data so the app can be resumed
cleanly with ./scripts/k8s-start.sh.

Options:
  --wait       Wait for scale-down completion before returning
  -h, --help   Show this help message
EOF
}

WAIT_FOR_DELETE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FOR_DELETE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "[memflip-k8s] Namespace ${NAMESPACE} does not exist; nothing to stop"
  exit 0
fi

echo "[memflip-k8s] Scaling application workloads down"
for deploy in "${DEPLOYMENTS[@]}"; do
  kubectl scale deployment/"${deploy}" -n "${NAMESPACE}" --replicas=0 >/dev/null 2>&1 || true
done

echo "[memflip-k8s] Scaling stateful workloads down"
for sts in "${STATEFULSETS[@]}"; do
  kubectl scale statefulset/"${sts}" -n "${NAMESPACE}" --replicas=0 >/dev/null 2>&1 || true
done

if [[ "${WAIT_FOR_DELETE}" -eq 1 ]]; then
  echo "[memflip-k8s] Waiting for controller scale-down"
  deadline=$((SECONDS + 600))
  while true; do
    deploy_replicas_ok=1
    for deploy in "${DEPLOYMENTS[@]}"; do
      replicas="$(kubectl get deployment/"${deploy}" -n "${NAMESPACE}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
      if [[ -n "${replicas}" && "${replicas}" != "0" ]]; then
        deploy_replicas_ok=0
        break
      fi
    done

    stateful_replicas_ok=1
    for sts in "${STATEFULSETS[@]}"; do
      replicas="$(kubectl get statefulset/"${sts}" -n "${NAMESPACE}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
      ready_replicas="$(kubectl get statefulset/"${sts}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
      if [[ -n "${replicas}" && "${replicas}" != "0" ]]; then
        stateful_replicas_ok=0
        break
      fi
      if [[ -n "${ready_replicas}" && "${ready_replicas}" != "0" ]]; then
        stateful_replicas_ok=0
        break
      fi
    done

    if [[ "${deploy_replicas_ok}" -eq 1 && "${stateful_replicas_ok}" -eq 1 ]]; then
      break
    fi

    if (( SECONDS >= deadline )); then
      echo "[memflip-k8s] ERROR: Timed out waiting for MemFlip controller scale-down" >&2
      kubectl get deploy,statefulset,pods -n "${NAMESPACE}" >&2 || true
      exit 1
    fi
    sleep 5
  done
fi
