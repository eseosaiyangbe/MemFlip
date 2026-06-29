# Cloud CI/CD

MemFlip now follows a cleaner cloud delivery contract:

1. `validate.yml`
   - repository integrity
   - dependency installation
   - frontend build
   - Kubernetes render and dry-run checks

2. `publish-ghcr-images.yml`
   - publishes backend and frontend images to GHCR
   - does not mutate GitOps manifests

3. `publish-aws-ecr.yml`
   - publishes backend and frontend images to Amazon ECR
   - does not mutate GitOps manifests

4. `promote-aws-gitops.yml`
   - verifies immutable ECR images exist
   - updates `gitops-safe/overlays/aws/kustomization.yaml`
   - creates a pull request instead of mutating the cluster directly

## Why this is better

- validation is isolated from image publishing
- image publishing is isolated from GitOps promotion
- AWS promotion updates the AWS overlay instead of polluting the GitOps base
- production release stays reviewable and auditable

## Current promotion commands

For GHCR-backed local or dev paths, use the GitOps manifests already tracked in the repository.

For AWS:

1. publish images with `.github/workflows/publish-aws-ecr.yml`
2. run `.github/workflows/promote-aws-gitops.yml`
3. review and merge the promotion pull request
4. let Argo CD reconcile from `gitops-safe/overlays/aws`
