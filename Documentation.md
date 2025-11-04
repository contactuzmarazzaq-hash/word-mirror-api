# Word Mirror API

## Infrastructure Setup using Terraform

The infrastructure for this project is defined using Terraform and deployed on **Azure**. The following resources were provisioned:

- **Resource Group**
  - Name: `mirror-rg`
  - Location: `West US`

- **Azure Container Registry (ACR)**
  - Name: `mirroracr51258`
  - SKU: `Basic`
  - Admin enabled: `true`
  - Used to store Docker images

- **PostgreSQL Flexible Server**
  - Name: `mirrorpg51258`
  - Version: `14`
  - Admin login: `pgadmin`
  - Password: Generated randomly
  - Storage: 32 GB
  - Firewall: Allows public access (0.0.0.0 – 255.255.255.255)
  - Stores `<word, mirroredWord>` pairs

- **Azure Kubernetes Service (AKS)**
  - Name: `mirror-aks`
  - Node pool:
    - Count: 1
    - VM size: Standard_B4ms (4 vCPU, 16 GB RAM)
  - System-assigned identity for ACR pull
  - Role assignment: AKS can pull images from ACR

- **Outputs**
  - `acr_login_server`
  - `pg_fqdn`
  - `pg_user`
  - `pg_password` (sensitive)
  - `aks_cluster_name`
  - `aks_kube_config` (sensitive)
  - `postgres_connection_url` (sensitive)

---

## Application Deployed Using Kubernetes

- **Deployment**
  - Name: `mirror-app`
  - Container image: `mirroracr51258.azurecr.io/word-mirror-api:<build_id>`
  - Replicas: 1

- **Service**
  - Type: `ClusterIP` (internal)
  - Exposes port 4004 of the application

- **Ingress**
  - Exposes the app on port 80
  - Routes `/api/health` and `/api/mirror` to the application service

- **Secrets**
  - PostgreSQL credentials (`pg_user` and `pg_password`)
  - ACR credentials for Kubernetes to pull Docker images

- **Pods**
  - 1 pod running `mirror-app` container
  - Automatically pulls latest Docker image from ACR on deployment

---

## App is Accessible To

- Health endpoint:  

http://20.57.194.247/api/health

**Response:** `{ "status": "ok" }`

- Mirror endpoint:  

http://20.57.194.247/api/mirror?word=Hello

**Response:** `{ "transformed": "OLLEh" }`

> Current deployed AKS public IP: `http://20.57.194.247`

---

## Azure DevOps CI/CD

- Original plan was to use Azure DevOps pipelines for:
- Running Node.js tests
- Building Docker image
- Pushing image to ACR
- Deploying to AKS

- **Reason not used:** Free-tier Azure DevOps does not allow hosted parallelism for private repos.  
- **Solution:** Code was moved to GitHub and GitHub Actions CI/CD was implemented instead.

---

## Local Deployment Steps

1. **Azure Login**
 ```bash
 az login

2. Terraform

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

This will provision resource group, ACR, PostgreSQL server, AKS, and role assignments.

3. Docker

docker build -t mirroracr51258.azurecr.io/word-mirror-api:<tag> .
docker push mirroracr51258.azurecr.io/word-mirror-api:<tag>

4. Kubernetes Deployment

# Create namespace if needed
kubectl create namespace default

# Create secrets
kubectl create secret generic pg-secret \
  --from-literal=pg_user=<username> \
  --from-literal=pg_password=<password> -n default

kubectl create secret docker-registry acr-secret \
  --docker-server=mirroracr51258.azurecr.io \
  --docker-username=mirroracr51258 \
  --docker-password=<password> -n default

# Apply manifests
kubectl apply -f kubernetes/deployment.yaml -n default
kubectl apply -f kubernetes/service.yaml -n default
kubectl apply -f kubernetes/ingress.yml -n default

5. Verify Deployment

kubectl get pods -n default
kubectl get svc -n default
kubectl get ingress -n default
