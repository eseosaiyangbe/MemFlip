#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="memflip-dev"
BUILD_IMAGES=0
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
Usage: ./scripts/k8s-start.sh [options] [-- <extra deploy args>]

Start the MemFlip dev overlay in the current Kubernetes context.

By default, this reuses existing local images. Use --build when you
intentionally want fresh local image builds.

Options:
  --build      Rebuild images before deploy
  -h, --help   Show this help message
EOF
}

extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      BUILD_IMAGES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

resume_existing_namespace() {
  echo "[memflip-k8s] Existing ${NAMESPACE} namespace detected; resuming preserved workloads"

  echo "[memflip-k8s] Scaling stateful workloads back up"
  for sts in "${STATEFULSETS[@]}"; do
    kubectl scale statefulset/"${sts}" -n "${NAMESPACE}" --replicas=1
  done

  echo "[memflip-k8s] Waiting for stateful workload readiness"
  for sts in "${STATEFULSETS[@]}"; do
    kubectl rollout status statefulset/"${sts}" -n "${NAMESPACE}" --timeout=300s
  done

  echo "[memflip-k8s] Scaling application workloads back up"
  for deploy in "${DEPLOYMENTS[@]}"; do
    kubectl scale deployment/"${deploy}" -n "${NAMESPACE}" --replicas=1
  done

  echo "[memflip-k8s] Waiting for application rollouts"
  for deploy in "${DEPLOYMENTS[@]}"; do
    kubectl rollout status deployment/"${deploy}" -n "${NAMESPACE}" --timeout=300s
  done
}

cmd=("${ROOT_DIR}/scripts/k8s-dev-deploy.sh")
if [[ "${BUILD_IMAGES}" -eq 0 ]]; then
  cmd+=(--skip-build)
fi
if [[ "${#extra_args[@]}" -gt 0 ]]; then
  cmd+=("${extra_args[@]}")
fi

if [[ "${BUILD_IMAGES}" -eq 0 ]] && kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  resume_existing_namespace
  exit 0
fi

exec "${cmd[@]}"
