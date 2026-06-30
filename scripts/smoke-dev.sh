#!/usr/bin/env bash
set -euo pipefail

APP_NS="memflip-dev"
ARGO_NS="argocd"
APP_NAME="memflip-dev"
URL="${URL:-https://memflip.eseosadevbox.com}"
UA="Mozilla/5.0"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require kubectl
require curl

printf '==> Argo CD application status\n'
kubectl get applications.argoproj.io -n "$ARGO_NS" "$APP_NAME"

printf '\n==> Workload status\n'
kubectl get deploy,pods,svc,ingress -n "$APP_NS"

printf '\n==> Public HTTP checks\n'
curl -k -I -A "$UA" "$URL/"
printf '\n'
curl -k -I -A "$UA" "$URL/api/health"

printf '\n==> Smoke result\n'
printf 'dev smoke checks completed successfully for %s\n' "$URL"
