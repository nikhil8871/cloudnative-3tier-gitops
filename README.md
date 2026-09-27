# Cloud-Native 3-Tier GitOps Architecture

Enterprise-ready 3-Tier cloud application (React, Node.js, AWS RDS MySQL) deployed on Kubernetes using GitOps continuous delivery via ArgoCD, Infrastructure as Code (IaC) via Terraform, and automated Continuous Integration (CI) via GitHub Actions.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![AWS RDS](https://img.shields.io/badge/AWS_RDS-527FFF?style=for-the-badge&logo=amazon-aws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)

---

## 🏗️ Architecture Overview

The system is architected across three distinct tiers with strict network isolation and declarative GitOps automation:

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
│ • terraform init        │             │ • Docker build & push   │             │ • Validate manifests    │
│ • terraform validate    │             │ • Tag SHA, v1, latest   │             │ • Check API versions    │
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
        │  │                            │    [ Ingress / Frontend Service (LoadBalancer :80) ]    │
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
│  • Public Subnet: 10.0.1.0/24 (Internet Gateway + NAT Gateway)  │  │ over port 3306
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

## ☸️ GitOps with ArgoCD: Deep Dive into `application.yaml`

The file [`k8s/argocd/application.yaml`](k8s/argocd/application.yaml) represents the GitOps engine of this project. Below is an exhaustive breakdown of every field, its operational meaning, and why it is configured this way:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: three-tier-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: "https://github.com/nikhil8871/cloudnative-3tier-gitops.git"
    targetRevision: HEAD
    path: k8s
    directory:
      recurse: true
  destination:
    server: "https://kubernetes.default.svc"
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Detailed Field Breakdown

| Line / Field | Technical Meaning (What it does) | Architectural Rationale (Why we use it) |
| :--- | :--- | :--- |
| **`apiVersion: argoproj.io/v1alpha1`** | Identifies the schema version of the ArgoCD Custom Resource Definition (CRD). | **Production Standard:** Although named `alpha1`, this is the permanent, standard CRD version used across all ArgoCD v1.x and v2.x releases for backward compatibility. |
| **`kind: Application`** | Specifies the Kubernetes resource type. | Tells the ArgoCD controller to track and sync a continuous deployment unit between Git and Kubernetes. |
| **`metadata.name: three-tier-app`** | The unique identifier of this deployment unit. | Displayed as the top-level card in the ArgoCD Web UI and referenced in CLI operations (`argocd app get three-tier-app`). |
| **`metadata.namespace: argocd`** | Specifies the namespace where the Application custom resource resides. | The ArgoCD controller process runs inside the `argocd` namespace and watches this namespace for application definitions. |
| **`finalizers: - resources-finalizer.argocd.argoproj.io`** | Enables **Cascade Deletion**. | **Prevents Zombie Resources:** If this Application is ever deleted, ArgoCD automatically cleans up all associated Deployments, Services, and ConfigMaps from the cluster. *(Note: Does not affect Terraform-managed AWS cloud infrastructure).* |
| **`spec.project: default`** | Assigns the app to an ArgoCD `AppProject` logical security boundary. | **Mandatory Field:** ArgoCD requires every app to belong to a project. The built-in `default` project allows deployments from any repository to any cluster without requiring custom RBAC policies. |
| **`source.repoURL`** | The Git repository location. | Serves as the **Single Source of Truth** for all cluster configurations. |
| **`source.targetRevision: HEAD`** | Specifies the Git ref (branch, tag, or commit) to track. | `HEAD` tracks the latest commit on the repository's default branch (`main`), deploying new changes immediately upon push. |
| **`source.path: k8s`** | The root folder inside the repository containing manifests. | Isolates application deployment manifests from application source code (`backend/`, `frontend/`) and Terraform files (`terraform_files/`). |
| **`source.directory.recurse: true`** | Enables recursive scanning of subdirectories. | Manifests are organized into domain folders (`k8s/backend/`, `k8s/frontend/`, `k8s/database/`). Without recursion, ArgoCD would only read manifests in the root of `k8s/`. |
| **`destination.server: "https://kubernetes.default.svc"`** | The API server endpoint of the target Kubernetes cluster. | **In-Cluster DNS:** Refers to the local Kubernetes cluster where ArgoCD is running. |
| **`destination.namespace: default`** | Target namespace for application workloads. | Deploys the Frontend, Backend, and Database objects into the `default` namespace. |
| **`syncPolicy.automated`** | Enables continuous reconciliation without manual button clicks. | Pure GitOps automation: changes pushed to `main` are automatically detected and deployed within minutes. |
| **`syncPolicy.automated.prune: true`** | Automatically deletes Kubernetes objects if their YAML file is removed from Git. | Guarantees exact 1:1 synchronization with Git. Deleting a resource file in Git immediately deletes it from the live cluster. |
| **`syncPolicy.automated.selfHeal: true`** | Automatically overwrites manual cluster edits. | **Prevents Configuration Drift:** If an engineer manually modifies or deletes a pod or service via `kubectl`, ArgoCD immediately overrides the drift and restores the Git-defined state. |
| **`syncOptions: - CreateNamespace=true`** | Pre-creates the destination namespace if it does not already exist. | Prevents deployment failures caused by missing Kubernetes namespaces. |

---

### Comparison: `Application` vs. `ApplicationSet`

| Feature | `Application` (Current Setup) | `ApplicationSet` (Multi-Cluster / EKS) |
| :--- | :--- | :--- |
| **Cardinality** | 1 Manifest = 1 Target Deployment | 1 Manifest = Generator for Multiple Applications |
| **Target** | Single Cluster / Single Namespace (`Stage`) | Multi-Environment (`dev`, `staging`, `prod`) or Multi-Cluster (EKS) |
| **Generators** | None (Static definition) | List, Git Directory, Cluster, Pull Request generators |
| **Best Used For** | Staging / Single-Cluster workloads | Scaling to Production across AWS EKS clusters |

---

## ⚡ CI/CD Pipelines (GitHub Actions)

This repository implements **smart path filtering** to optimize runner minutes and build times:

| Pipeline | Trigger Path | Operations Executed |
| :--- | :--- | :--- |
| **`terraform-ci.yaml`** | `terraform_files/**` | • `terraform fmt -check`<br>• `terraform init -backend=false`<br>• `terraform validate` |
| **`app-ci.yaml`** | `backend/**`, `frontend/**`, `Docker-Compose.yml` | • Node.js 18 dependency validation (`npm ci`)<br>• Docker Buildx compilation<br>• Authenticated login to Docker Hub<br>• Builds & pushes `nikhil8871/3-tier-backend` & `nikhil8871/3-tier-frontend` (tagged `:SHA`, `:v1`, `:latest`) |
| **`k8s-validate.yaml`** | `k8s/**` | • Recursive Python YAML parser (`yaml.safe_load_all`)<br>• Syntax and indentation safety verification prior to ArgoCD sync |

---

## 📁 Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── app-ci.yaml             # Docker build, test & push pipeline
│       ├── k8s-validate.yaml       # Kubernetes YAML syntax validator
│       ├── terraform-ci.yaml       # Terraform linting & validation
│       └── README.md               # Detailed CI/CD workflow docs
├── backend/                        # Node.js Express REST API
│   ├── DbConfig.js                 # MySQL database connection pool
│   ├── TransactionService.js       # Transaction business logic
│   ├── Dockerfile                  # Production container definition
│   └── package.json
├── frontend/                       # React 18 Single-Page Application
│   ├── src/                        # Styled React UI components
│   ├── nginx.conf                  # Nginx reverse proxy configuration
│   ├── Dockerfile                  # Multi-stage production container
│   └── package.json
├── k8s/                            # Declarative Kubernetes Manifests
│   ├── argocd/
│   │   └── application.yaml        # ArgoCD GitOps Application manifest
│   ├── backend/
│   │   ├── deployment.yaml         # Backend pods (2 replicas)
│   │   └── service.yaml            # Internal ClusterIP (port 4000)
│   ├── database/
│   │   ├── configmap.yaml          # DB_HOST, DB_NAME, DB_USER
│   │   └── secret.yaml             # Base64-encoded DB credentials
│   └── frontend/
│       ├── deployment.yaml         # Frontend pods (2 replicas)
│       └── service.yaml            # External LoadBalancer (port 80)
├── terraform_files/                # AWS Infrastructure as Code
│   ├── vpc.tf                      # Custom VPC, Subnets, Gateways, Route Tables
│   ├── rds.tf                      # AWS RDS MySQL 8.0 Multi-AZ database
│   ├── aws_instance.tf             # EC2 Kubernetes host instance
│   ├── sg.tf                       # Tiered Security Groups
│   ├── key-pair.tf                 # SSH access keys
│   ├── provider.tf                 # AWS provider configuration
│   ├── var.tf                      # Configurable input variables
│   └── output.tf                   # RDS endpoint & connection details
├── docs/                           # Architectural diagrams and flowcharts
├── Docker-Compose.yml              # Local developer environment
└── README.md                       # Main project documentation
```

---

## 🚀 Quick Deployment Guide

### 1. Provision Infrastructure with Terraform
```bash
cd terraform_files
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Configure Kubernetes Secrets
Update `k8s/database/configmap.yaml` with the RDS endpoint from Terraform output, and encode your password in `k8s/database/secret.yaml`:
```bash
echo -n "YourSecurePassword" | base64
```

### 3. Deploy Application via ArgoCD
Apply the GitOps application controller manifest to your cluster:
```bash
kubectl apply -f k8s/argocd/application.yaml
```

ArgoCD will automatically discover the manifests, pull the container images from Docker Hub, provision the Kubernetes pods, and reconcile state continuously.
