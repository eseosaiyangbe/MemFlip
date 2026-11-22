# MemFlip Platform Architecture

![MemFlip platform architecture](memflip-platform-architecture.png)

This document is the architecture design of record for the MemFlip onboarding workload. The image above is rendered from the Mermaid source in this file, so the picture and the source never drift apart.

## The design in one paragraph

MemFlip is the platform's reference onboarding workload, and its architecture is the contract it demonstrates. The workload is deliberately small (frontend, backend, health endpoint) so the platform behaviour around it stays legible: Traefik ingress as the only public entry, network integration through Kubernetes Services, metrics and logs in the agreed shape flowing to the shared Prometheus, Grafana, and Loki stack, presence in the platform inventory beside the larger workloads, and Vault backed secret delivery through External Secrets Operator for both dev and prod. The runtime is the memflip-dev namespace on the Phase 7 Kubernetes path (k3s, Kustomize base plus dev and prod overlays, Argo CD wiring, state preserving lifecycle controls). Delivery follows the workspace model: validate, publish Docker Hub images, and smoke verification of the public dev edge, with a separate AWS cloud track (ECR publish and manual GitOps promotion) that is not the local dev runtime. Validation is contract compliance: the MemFlip live audit passed 34 of 34 checks (Phase 6 lab audit), and the backend unavailable drill (reachability checks, dependency inspection, recovery validated against the health endpoint, telemetry, and public reachability) proves the smallest workload carries the full failure model.

## Architecture diagram, Mermaid source

```mermaid
flowchart TB
    User["User"]
    Operator["Operator"]

    subgraph Edge["Edge and ingress"]
        CF["Cloudflare Tunnel<br/>memflip.eseosadevbox.com"]
        Traefik["Traefik ingress<br/>The only public entry"]
    end

    subgraph Cluster["Kubernetes on k3s, memflip-dev namespace"]
        subgraph Workload["The workload, deliberately small"]
            Frontend["MemFlip frontend<br/>Memory game UI"]
            Backend["MemFlip backend"]
            Health["Health endpoint<br/>A contract requirement,<br/>not an extra"]
            Frontend --> Backend
            Backend --> Health
        end

        subgraph Contract["The platform contract, what joining means"]
            Network["Network integration<br/>Kubernetes Services"]
            Telemetry["Metrics and logs<br/>In the agreed shape"]
            Lifecycle["Lifecycle controls<br/>State preserving start,<br/>stop, reset, verify"]
        end

        subgraph Obs["Observability, shared platform stack"]
            Prom["Prometheus<br/>Metrics"]
            Grafana["Grafana<br/>Dashboards"]
            Loki["Loki<br/>Logs"]
            Inventory["Platform inventory<br/>Listed beside the<br/>larger workloads"]
        end

        Workload --> Network
        Workload --> Telemetry
    end

    subgraph Secrets["Platform secrets"]
        Vault["HashiCorp Vault<br/>Source of truth"]
        ESO["External Secrets Operator<br/>Delivers for dev and prod"]
        Vault --> ESO
        ESO --> Workload
    end

    subgraph Delivery["Delivery"]
        Git["Git repository<br/>Kustomize base plus<br/>overlays, dev and prod"]
        CI["Validate, publish<br/>Docker Hub images"]
        Smoke["Smoke dev public<br/>Verifies the live dev edge"]
        AWSTrack["AWS cloud track<br/>ECR publish, manual GitOps<br/>promotion, separate path"]
        Git --> CI
        CI --> Cluster
        Smoke --> CF
    end

    subgraph Validation["Validation and drills"]
        Audit["MemFlip live audit<br/>34 of 34, Phase 6 lab audit"]
        Drill["Backend unavailable drill<br/>Reachability checks,<br/>dependency inspection"]
        Recovery["Recovery validation<br/>Health endpoint, telemetry,<br/>public reachability"]
        Audit --> Workload
        Drill --> Backend
        Recovery --> Health
    end

    User --> CF
    CF --> Traefik
    Traefik --> Frontend
    Telemetry --> Prom
    Telemetry --> Loki
    Prom --> Grafana
    Prom --> Inventory
    Grafana --> Operator
    Inventory --> Operator
```

## Flow diagram: onboarding a workload, Mermaid source

```mermaid
flowchart LR
    A["Adopt the contract<br/>Setup expectations,<br/>ports, aliases"] --> B["Provide the health endpoint<br/>Metrics and logs<br/>in the agreed shape"]
    B --> C["Deploy through the<br/>standard path<br/>Kustomize overlays"]
    C --> D["Receive platform services<br/>Ingress, network,<br/>Vault backed secrets"]
    D --> E["Appear in the platform<br/>inventory and the<br/>standard health workflow"]
    E --> F["Carry a drill<br/>Backend unavailable,<br/>recovery validated"]
    F --> E
```

## Notes

- Lab environment. Audit counts are point in time lab validation results documented in the platform repository.
- The older manifest set in this repository is learning path archive material, not the current deployment standard.
- Live application: `https://memflip.eseosadevbox.com`.
