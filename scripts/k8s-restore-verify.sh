#!/usr/bin/env sh
set -eu

NAMESPACE="${NAMESPACE:-memflip-dev}"
POD_NAME="${POD_NAME:-memflip-restore-verify}"
REDIS_PVC="${REDIS_PVC:-redis-data-memflip-redis-0}"
IMAGE="${IMAGE:-postgres:15-alpine}"
APP_CONFIG="${APP_CONFIG:-memflip-app-config}"
APP_SECRET="${APP_SECRET:-memflip-app-secrets}"

kubectl rollout status deployment/memflip-backend -n "${NAMESPACE}" --timeout=300s >/dev/null
kubectl rollout status deployment/memflip-frontend -n "${NAMESPACE}" --timeout=300s >/dev/null
kubectl rollout status statefulset/memflip-redis -n "${NAMESPACE}" --timeout=300s >/dev/null

kubectl delete pod -n "${NAMESPACE}" "${POD_NAME}" --ignore-not-found >/dev/null 2>&1 || true
trap 'kubectl delete pod -n "${NAMESPACE}" "${POD_NAME}" --ignore-not-found >/dev/null 2>&1 || true' EXIT

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    backup-role: state-backup
spec:
  restartPolicy: Never
  containers:
    - name: verify
      image: ${IMAGE}
      imagePullPolicy: IfNotPresent
      resources:
        requests:
          cpu: 25m
          memory: 64Mi
        limits:
          cpu: 150m
          memory: 128Mi
      env:
        - name: PGHOST
          value: memflip-postgres
        - name: PGPORT
          valueFrom:
            configMapKeyRef:
              name: ${APP_CONFIG}
              key: DB_PORT
        - name: PGUSER
          valueFrom:
            configMapKeyRef:
              name: ${APP_CONFIG}
              key: DB_USER
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: ${APP_SECRET}
              key: DB_PASSWORD
        - name: PGDATABASE
          valueFrom:
            configMapKeyRef:
              name: ${APP_CONFIG}
              key: DB_NAME
      command:
        - /bin/sh
        - -ec
        - |
          echo "Waiting for PostgreSQL at \${PGHOST}:\${PGPORT}"
          for _ in \$(seq 1 60); do
            if pg_isready -h "\${PGHOST}" -p "\${PGPORT}" -U "\${PGUSER}" -d "\${PGDATABASE}" >/dev/null 2>&1; then
              break
            fi
            sleep 2
          done

          echo "Verifying PostgreSQL restore state"
          psql -h "\${PGHOST}" -p "\${PGPORT}" -U "\${PGUSER}" -d "\${PGDATABASE}" -v ON_ERROR_STOP=1 -c "
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename IN ('users', 'games', 'game_matches')
            ORDER BY tablename;
          "

          psql -h "\${PGHOST}" -p "\${PGPORT}" -U "\${PGUSER}" -d "\${PGDATABASE}" -v ON_ERROR_STOP=1 -c "
            SELECT
              (SELECT COUNT(*) FROM users) AS users,
              (SELECT COUNT(*) FROM games) AS games,
              (SELECT COUNT(*) FROM game_matches) AS game_matches;
          "

          echo "Verifying Redis primary PVC data files"
          if [ ! -f /redis-data/dump.rdb ]; then
            echo "ERROR: Redis dump.rdb not present on restored PVC" >&2
            exit 1
          fi
          find /redis-data -maxdepth 2 -type f | sort
      volumeMounts:
        - name: redis-storage
          mountPath: /redis-data
  volumes:
    - name: redis-storage
      persistentVolumeClaim:
        claimName: ${REDIS_PVC}
EOF

for _ in $(seq 1 300); do
  phase="$(kubectl get pod -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [ "${phase}" = "Succeeded" ] || [ "${phase}" = "Failed" ]; then
    break
  fi
  sleep 1
done

kubectl logs -n "${NAMESPACE}" "${POD_NAME}"
phase="$(kubectl get pod -n "${NAMESPACE}" "${POD_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [ "${phase}" != "Succeeded" ]; then
  echo "ERROR: verify pod ended in phase ${phase:-Unknown}" >&2
  exit 1
fi
