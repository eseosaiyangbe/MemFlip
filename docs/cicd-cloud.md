# Cloud CI/CD

MemFlip now follows a cleaner cloud delivery contract:

1. `validate.yml`
   - repository integrity
   - dependency installation
   - frontend build
   - Kubernetes render and dry-run checks

2. `publish-dockerhub-images.yml`
   - publishes backend and frontend images to Docker Hub
   - does not mutate GitOps manifests

3. `smoke-dev-public.yml`
   - verifies the active public `dev` edge
   - keeps the current runtime truth separate from dormant local `prod` intent

4. `publish-aws-ecr.yml`
   - publishes backend and frontend images to Amazon ECR
   - does not mutate GitOps manifests

5. `promote-aws-gitops.yml`
   - verifies immutable ECR images exist
   - updates `gitops-safe/overlays/aws/kustomization.yaml`
   - creates a pull request instead of mutating the cluster directly

## Why this is better

- validation is isolated from image publishing
- active `dev` verification is isolated from both Docker Hub and AWS publishing
- image publishing is isolated from GitOps promotion
- AWS promotion updates the AWS overlay instead of polluting the GitOps base
- production release stays reviewable and auditable

## Current promotion commands

For the current local operating model:

1. `main` plus the mutable Docker Hub `dev` alias feeds the active `dev` narrative
2. `.github/workflows/smoke-dev-public.yml` verifies the active public `dev` edge
3. the local `prod` overlay remains held contract material rather than the active runtime path

For AWS:

1. publish images with `.github/workflows/publish-aws-ecr.yml`
2. run `.github/workflows/promote-aws-gitops.yml`
3. review and merge the promotion pull request
4. let Argo CD reconcile from `gitops-safe/overlays/aws`
