# DevOps Dashboard API

A REST API for tracking deployments across services. Built with Node.js + PostgreSQL,
deployed on Kubernetes (EKS) using Docker, Terraform, and GitHub Actions.

---

## What's new vs a basic project

| Concept | What you'll learn |
|---------|-------------------|
| **Namespaces** | Separate `app` and `database` pods inside one cluster |
| **StatefulSet** | How to run a database (PostgreSQL) on Kubernetes |
| **Kubernetes Secrets** | Inject passwords without hardcoding them |
| **ConfigMap + Secret together** | Non-sensitive config vs sensitive config |
| **Multi-stage Docker** | Build + test in one stage, lean image in another |
| **HPA** | Auto-scale pods when CPU is high |

---

## Project structure

```
devops-dashboard/
├── src/
│   ├── index.js               ← Express app entry point
│   ├── db/index.js            ← PostgreSQL connection + table setup
│   ├── routes/
│   │   ├── deployments.js     ← GET/POST /api/deployments
│   │   └── services.js        ← GET/POST /api/services
│   └── middleware/logger.js   ← JSON request logger
├── tests/
│   └── app.test.js            ← Jest tests (DB is mocked)
├── k8s/
│   ├── namespace/
│   │   └── namespaces.yaml    ← creates "app" and "database" namespaces
│   ├── database/
│   │   ├── postgres-statefulset.yaml  ← PostgreSQL on Kubernetes
│   │   └── postgres-secret.yaml       ← DB credentials as K8s Secret
│   └── app/
│       ├── configmap.yaml     ← non-sensitive env vars
│       ├── deployment.yaml    ← app Deployment with rolling updates
│       └── service-hpa.yaml   ← LoadBalancer Service + HPA autoscaler
├── terraform/
│   └── main.tf                ← VPC + ECR + EKS
├── .github/workflows/
│   ├── ci.yml                 ← runs on PR: test + docker build check
│   └── cd.yml                 ← runs on merge: build → push → deploy
├── Dockerfile                 ← multi-stage build
└── docker-compose.yml         ← local dev with postgres
```

---

## Run locally (no AWS needed)

```bash
# Option A: Node + local postgres via Docker Compose (recommended)
docker-compose up --build

# Option B: Just run tests (no database needed — DB is mocked)
npm install && npm test
```

App will be available at http://localhost:3000

Try the API:
```bash
# Get all deployments
curl http://localhost:3000/api/deployments

# Trigger a new deployment
curl -X POST http://localhost:3000/api/deployments/trigger \
  -H "Content-Type: application/json" \
  -d '{"service": "auth-service", "version": "v2.0", "triggered_by": "sultan"}'

# Check deployment status (use the id from the response above)
curl http://localhost:3000/api/deployments/1

# List all services
curl http://localhost:3000/api/services
```

---

## Deploy to AWS

### 1. Provision infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Copy the `ecr_url` output value. Paste it into `k8s/app/deployment.yaml`,
replacing the line that says `YOUR_ECR_URL/devops-dashboard:latest`.

### 2. Add GitHub Secrets

Go to your repo → Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

### 3. Connect kubectl to EKS

Run the command from terraform output:
```bash
aws eks update-kubeconfig --name devops-dashboard-cluster --region us-east-1
```

### 4. Apply Kubernetes manifests (first time)

```bash
# Must apply in this order — namespaces first, then everything inside them
kubectl apply -f k8s/namespace/
kubectl apply -f k8s/database/
kubectl apply -f k8s/app/

# Check everything is running
kubectl get pods -n app
kubectl get pods -n database

# Get your app's public URL
kubectl get service devops-dashboard -n app
# Look at EXTERNAL-IP — that's your URL
```

### 5. After setup — all deployments are automatic

Push to a branch → open PR → CI runs tests → merge → CD deploys to EKS.

---

## Kubernetes concepts used

**Namespace** — like a folder in a cluster. `app` namespace holds the API. `database` namespace holds PostgreSQL. They're isolated from each other.

**Deployment** — manages the Node.js pods. Keeps 2 replicas running. Handles rolling updates (zero downtime).

**StatefulSet** — manages the PostgreSQL pod. Unlike a Deployment, each pod gets its own persistent volume so data survives restarts.

**Secret** — stores passwords as base64 values. Kubernetes injects them as environment variables at runtime. Never hardcode credentials.

**ConfigMap** — stores non-sensitive config (NODE_ENV, PORT). Same idea as Secret but for non-sensitive values.

**HPA** — Horizontal Pod Autoscaler. Watches CPU usage. Adds pods when load increases, removes them when it drops.

**Service (LoadBalancer)** — gives the pods a stable URL. AWS creates a real load balancer in front of your pods.

---

## Useful commands

```bash
# Watch pods in real time
kubectl get pods -n app -w

# App logs
kubectl logs -l app=devops-dashboard -n app --tail=50 -f

# Postgres logs
kubectl logs -l app=postgres -n database --tail=50

# Check HPA status (shows current vs desired replicas)
kubectl get hpa -n app

# Describe a pod (useful for debugging startup issues)
kubectl describe pod -l app=devops-dashboard -n app

# Destroy all AWS resources
cd terraform && terraform destroy
```
