# End-to-End GitOps Workflow Diagram

<p align="center">
  <img src="architecture-diagram.jpg" alt="Cloud-Native 3-Tier GitOps Architecture Diagram" width="100%" />
</p>

```text
===================================================================================================
                                      1. DEVELOPER WORKFLOW
===================================================================================================
                                                │
                                        git push│
                                                ▼
===================================================================================================
                                     2. GITHUB REPOSITORY
===================================================================================================
        │                                       │                                       │
 changes to:                             changes to:                             changes to:
 terraform_files/**                      backend/** & frontend/**                k8s/**
        │                                       │                                       │
        ▼                                       ▼                                       ▼
┌─────────────────────────┐             ┌─────────────────────────┐             ┌─────────────────────────┐
│      TERRAFORM CI       │             │     APPLICATION CI      │             │       K8S LINT CI       │
│                         │             │                         │             │                         │
│ • terraform fmt         │             │ • npm test & build      │             │ • Validate YAML syntax  │
│ • terraform init        │             │ • Docker build          │             │ • Validate manifests    │
│ • terraform validate    │             │ • Tag with commit SHA   │             │ • Check API versions    │
└─────────────────────────┘             └─────────────────────────┘             └─────────────────────────┘
        │                                       │
deploys │                                pushes │
infra   │                                image  │
        │                                       ▼
        │                               ┌─────────────────────────┐
        │                               │  DOCKER HUB REGISTRY    │
        │                               │                         │
        │                               │ • 3-tier-frontend:v1    │
        │                               │ • 3-tier-backend:v1     │
        │                               └─────────────────────────┘
        │                                            │
        │                                            │ pulls new
        │                                            │ images
        │                                            ▼
        │                               ┌─────────────────────────┐
        │       Monitors Git repo       │         ARGOCD          │
        │  ┌─────────────────────────── │  (CONTINUOUS DELIVERY)  │
        │  │                            └─────────────────────────┘
        │  │                                         │
        │  │ k8s/ manifests                          │ auto-syncs desired state
        │  │ (Single Source of Truth)                ▼
        │  │                            ┌─────────────────────────────────────────────────────────┐
        │  │                            │             KUBERNETES CLUSTER (K8s RUNTIME)            │
        │  │                            │                                                         │
        │  │                            │    [ External ALB :80 (Public Subnet) ──► NodePort :30080 ]    │
        │  │                            │                            │                            │
        │  │                            │                            ▼                            │
        │  │                            │    ┌───────────────────────────────────────────────┐    │
        │  │                            │    │ Frontend Pods (React UI + Nginx Reverse Proxy)│    │
        │  │                            │    └───────────────────────────────────────────────┘    │
        │  │                            │                            │                            │
        │  │                            │               proxy_pass   │ http://backend-service:4000│
        │  │                            │                            ▼                            │
        │  │                            │         [ Backend Service (ClusterIP :4000) ]           │
        │  │                            │                            │                            │
        │  │                            │                            ▼                            │
        │  │                            │    ┌───────────────────────────────────────────────┐    │
        │  │                            │    │       Backend Pods (Node.js REST API)         │    │
        │  │                            │    └───────────────────────────────────────────────┘    │
        │  │                            └────────────────────────────┬────────────────────────────┘
        ▼  ▼                                                         │
┌─────────────────────────────────────────────────────────────────┐  │
│                       AWS CLOUD (VPC)                           │  │
│                                                                 │  │
│  • VPC: 10.0.0.0/16 (us-west-1)                                 │  │ connects securely
│  • Public Subnet: 10.0.1.0/24 (Route 53 + ALB + NAT Gateway)    │  │ over port 3306
│  • Private Compute Subnet: 10.0.3.0/24 (K8s Nodes)              │  │
│  • Private Database Subnets: 10.0.5.0/24 & 10.0.6.0/24 (Multi-AZ│  │
│                                                                 │  │
│      ┌──────────────────────────────────────────────────┐       │  │
│      │            AWS RDS MySQL 8.0 Instance            │ <─────┘──┘
│      │                   (dev-mysql-db)                 │
│      └──────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

---

## 📌 Architectural Breakdown

### 1. Developer Workflow & Monorepo Path Filtering
* **Separation of Concerns:** Changes to infrastructure (`terraform_files/**`), application source code (`backend/**`, `frontend/**`), and deployment manifests (`k8s/**`) trigger distinct, isolated GitHub Actions workflows.
* **Resource Optimization:** Docker builds are not triggered for Terraform-only changes, and Terraform plans are not run for frontend CSS/JS updates.

### 2. GitOps Continuous Delivery (ArgoCD)
* **Single Source of Truth:** The `k8s/` directory in this GitHub repository holds the declarative target state for the entire cluster.
* **Automated Reconciliation:** The ArgoCD controller polls the repository, detects any drift between the live cluster state and Git, and automatically self-heals without manual `kubectl` intervention.
* **Sync Waves:** Enforces controlled deployment order (`Wave 1: Configs/Secrets` → `Wave 2: Backend + wait-for-db InitContainer` → `Wave 3: Frontend`).

### 3. Application Runtime Flow
1. **User Request:** Traffic enters via Amazon Route 53 DNS and hits the External Application Load Balancer (ALB) on port `80` in the Public Subnet.
2. **Compute Ingress:** The ALB forwards traffic to Kubernetes Worker Nodes on NodePort `30080`.
3. **Reverse Proxy:** The React frontend Nginx reverse proxy serves UI static assets and transparently proxies `/api/*` requests internally to `http://backend-service:4000/`.
4. **Cluster Routing:** Kubernetes routes internal traffic across backend pods via ClusterIP service resolution.
5. **Data Isolation:** Backend pods connect to AWS RDS MySQL over port `3306` inside private database subnets with credentials injected via Kubernetes Secrets.
