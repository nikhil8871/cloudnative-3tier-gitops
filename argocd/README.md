# ArgoCD GitOps Continuous Delivery

This directory contains the declarative GitOps Application manifest for automated continuous delivery of the 3-Tier cloud application onto Kubernetes.

---

## 📄 Manifest: `application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: three-tier-app-v1
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

---

## ❓ Architectural FAQ: Why 2 Different Namespaces?

In `application.yaml`, two separate namespaces are defined:
* `metadata.namespace: argocd` (Line 5)
* `spec.destination.namespace: default` (Line 18)

> **"If ArgoCD and Kubernetes run on a single machine / Master node, why do we need two different namespaces?"**

### Visual Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES CLUSTER (Node)                             │
│                                                                                 │
│   ┌────────────────────────────────┐       ┌────────────────────────────────┐   │
│   │      Namespace: "argocd"       │       │      Namespace: "default"      │   │
│   │    (The Deployment Engine)     │       │    (Your 3-Tier Application)   │   │
│   │                                │       │                                │   │
│   │ • argocd-server                │       │ • Frontend Pods (React)        │   │
│   │ • argocd-repo-server           │Deploy │ • Backend Pods (Node.js)       │   │
│   │ • argocd-controller ──────────┼──────>│ • Database ConfigMap & Secrets │   │
│   │ • Application CRD              │       │ • Services (Port 80, 4000)     │   │
│   │   (three-tier-app-v1)          │       │                                │   │
│   └────────────────────────────────┘       └────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1. Separation of Responsibilities

| Namespace | Role in the System | What Lives Here |
| :--- | :--- | :--- |
| **`argocd`** | **Management / Control Plane** | The ArgoCD controller, repo server, API server, Redis cache, and GitOps tracking objects (`Application`). |
| **`default`** | **Workload / Data Plane** | The actual application workloads: React frontend pods, Node.js API pods, in-cluster services, and database configs. |

* **`metadata.namespace: argocd`**: Tells Kubernetes: *"Store this Application tracking ticket in the `argocd` namespace where the ArgoCD controller watches for jobs."*
* **`spec.destination.namespace: default`**: Tells ArgoCD: *"When deploying the manifests (`backend`, `frontend`, `database`), create the actual running pods and services in the `default` namespace."*

---

### 2. Why Isolating Namespaces is Best Practice

Even on a single-node or master-only cluster, separating tools from user applications is standard production hygiene:

1. **Security & Principle of Least Privilege (RBAC):**
   * ArgoCD requires cluster-level administrative permissions, GitHub tokens, and cluster secrets.
   * If an attacker compromises a vulnerability in the public-facing React frontend or Node.js backend, they are strictly contained inside the `default` namespace and **cannot access ArgoCD's administrative credentials or cluster-admin tokens**.

2. **Blast Radius & Crash Isolation:**
   * If a memory leak in the Node.js backend or a traffic spike causes pods to be terminated (`OOMKilled`), it only affects the `default` namespace.
   * The **ArgoCD control plane remains healthy and operational**, allowing you to rollback or redeploy without downtime of your deployment infrastructure.

3. **Node vs. Namespace Boundary:**
   * A **Node** is a compute resource (hardware, VM, or EC2 instance).
   * A **Namespace** is a logical isolation boundary inside the Kubernetes software layer.
   * Even on a single node, namespaces prevent naming collisions, allow independent resource quotas, and separate system software from business applications.

4. **Clean Lifecycle Management:**
   * If you need to wipe out and reset the application (`kubectl delete -f k8s/`), only the application workloads are purged. ArgoCD stays running and ready to redeploy immediately.

---

## 📋 Comprehensive Line-by-Line Breakdown

| Field | What It Does (Technical Function) | Why It Is Used (Architectural Reason) |
| :--- | :--- | :--- |
| **`apiVersion: argoproj.io/v1alpha1`** | Specifies the schema version for the ArgoCD Application CRD. | Permanent, production-stable CRD version across all ArgoCD v1.x and v2.x releases. |
| **`kind: Application`** | Declares the Kubernetes resource type. | Instructs ArgoCD to track a continuous deployment link between Git and the cluster. |
| **`metadata.name: three-tier-app-v1`** | Unique name for this application. | Appears on the ArgoCD Web UI dashboard and in CLI commands. |
| **`metadata.namespace: argocd`** | Namespace where the Application CRD is stored. | The ArgoCD controller process watches the `argocd` namespace for application manifests. |
| **`finalizers: [resources-finalizer.argocd.argoproj.io]`** | Enables cascade deletion. | Ensures that if this Application is deleted, all associated Pods and Services in the cluster are also cleaned up to prevent orphaned resources. |
| **`spec.project: default`** | Assigns this app to an ArgoCD `AppProject`. | Required field. The built-in `default` project allows deployment to any cluster/namespace without custom RBAC rules. |
| **`source.repoURL`** | The Git repository location. | The Single Source of Truth for all cluster configurations. |
| **`source.targetRevision: HEAD`** | Specifies the Git branch/commit to track. | Tracks the latest commit on `main`, enabling instant GitOps synchronization upon push. |
| **`source.path: k8s`** | Directory containing the YAML manifests. | Isolates Kubernetes manifests from code (`backend/`, `frontend/`) and Terraform files (`terraform_files/`). |
| **`source.directory.recurse: true`** | Enables recursive scanning of subdirectories. | Allows organizing manifests into clean subfolders (`k8s/backend/`, `k8s/frontend/`, `k8s/database/`). |
| **`destination.server: "https://kubernetes.default.svc"`** | Internal cluster API endpoint. | In-cluster alias pointing directly to the cluster where ArgoCD is installed. |
| **`destination.namespace: default`** | Target namespace for application pods. | Deploys user-facing workloads into the `default` application namespace. |
| **`syncPolicy.automated`** | Enables automatic synchronization. | Eliminates manual "Sync" button clicks — pure automated GitOps delivery. |
| **`syncPolicy.automated.prune: true`** | Deletes resources removed from Git. | Keeps cluster state in 1:1 parity with Git repository. |
| **`syncPolicy.automated.selfHeal: true`** | Overwrites unauthorized manual edits. | Prevents configuration drift caused by manual `kubectl` intervention. |
| **`syncOptions: [CreateNamespace=true]`** | Pre-creates target namespace if missing. | Prevents deployment failures if the destination namespace does not exist. |

---

## 🛠️ Step-by-Step Operations Guide

### 1. Install ArgoCD on the Cluster (One-Time Setup)
```bash
# 1. Create the dedicated argocd namespace
kubectl create namespace argocd

# 2. Install ArgoCD components
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Wait for all pods to be in Running state
kubectl get pods -n argocd -w
```

### 2. Access the ArgoCD Web UI
```bash
# Port-forward the ArgoCD UI to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
* **URL:** `https://localhost:8080`
* **Username:** `admin`
* **Password:** Retrieve the auto-generated initial password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  ```

### 3. Deploy the 3-Tier Application
```bash
# Apply the GitOps application manifest
kubectl apply -f argocd/application.yaml
```

### 4. Verify Sync Status
```bash
# Check application status via kubectl
kubectl get application three-tier-app-v1 -n argocd

# View deployed application pods in the default namespace
kubectl get pods -n default -l app=frontend
kubectl get pods -n default -l app=backend
```
