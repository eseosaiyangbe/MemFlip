#!/usr/bin/env sh
set -eu

NAMESPACE="${NAMESPACE:-memflip-dev}"
CRONJOB_NAME="${CRONJOB_NAME:-memflip-state-backup}"
JOB_NAME="${JOB_NAME:-memflip-state-backup-manual}"

if ! kubectl get cronjob -n "${NAMESPACE}" "${CRONJOB_NAME}" >/dev/null 2>&1; then
  echo "ERROR: CronJob ${CRONJOB_NAME} not found in namespace ${NAMESPACE}" >&2
  exit 1
fi

kubectl delete job -n "${NAMESPACE}" "${JOB_NAME}" --ignore-not-found >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  if ! kubectl get job -n "${NAMESPACE}" "${JOB_NAME}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

kubectl create job -n "${NAMESPACE}" --from=cronjob/"${CRONJOB_NAME}" "${JOB_NAME}"
kubectl wait --for=condition=complete --timeout=600s job/"${JOB_NAME}" -n "${NAMESPACE}"

pod_name="$(kubectl get pod -n "${NAMESPACE}" -l job-name="${JOB_NAME}" -o jsonpath='{.items[0].metadata.name}')"
kubectl logs -n "${NAMESPACE}" "${pod_name}" -c postgres-backup
kubectl logs -n "${NAMESPACE}" "${pod_name}" -c redis-backup
