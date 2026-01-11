Cluster: Talos Linux (Kubernetes v1.33.4)  
Cloud: Hetzner Cloud — Location: `hel1` (Helsinki)  
GitOps: FluxCD  
Ingress:Cloudflare Tunnel Ingress Controller  
Public App: https://kalyani.sfslab.cloud

---

## 1. Overview

This repository contains the GitOps-managed manifests for a Talos-based Kubernetes cluster deployed on Hetzner Cloud (hel1)via Terraform using the `hcloud-k8s/kubernetes/hcloud` module. After provisioning, FluxCD is bootstrapped to manage the cluster declaratively. A sample echo application is exposed publicly using **Cloudflare Tunnel Ingress Controller**.

Key outcomes:
- 3× control-plane + 1× worker nodes in `hel1` (Helsinki)
- Talos bootstrapped; kubeconfig & talosconfig exported
- FluxCD installed and reconciling from GitHub
- Cloudflare Tunnel Ingress working (automatic DNS + tunnel management)
- Public sample app available at [kalyani.sfslab.cloud](https://kalyani.sfslab.cloud/)`
- horizontal scaling(replicas increased and load balanced)

---

## 2. Repository Layout


talos-gitops/
└── clusters/
    └── production/
        ├── kalyani-demo/
        │   ├── namespace.yaml
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   ├── ingress.yaml
        │   └── kustomization.yaml
        │
        ├── Terraform/
        │   ├── .terraform.lock.hcl
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── terraform.tfvars
        │   ├── variables.tf
        │   └── versions.tf
        │
        └── kalyani-demo-kustomization.yaml

- `clusters/production/kalyani-demo/` → App manifests and a local `kustomization.yaml`
- `clusters/production/kalyani-demo-kustomization.yaml` → Flux Kustomization CR pointing to the demo folder

Flow :
GitHub Repo (manifests)
        │
        ▼
   FluxCD (GitOps)
        │
        ▼
Talos Kubernetes Cluster (Hetzner hel1)
  ├── 3 × CPX22 Control Plane
  └── 1 × CPX22 Worker
        │
        ▼
Cloudflare Tunnel Ingress Controller
        │  (Tunnel + DNS automation)
        ▼
https://kalyani.sfslab.cloud
        │
        ▼
EchoServer Application (5 replicas)

---

## 3. Provisioning (Terraform)

> Files kept on the workstation (VM): `~/sfs-assessment/terraform`

### 3.1 Module & Nodepools

- Module used: [hcloud-k8s/kubernetes/hcloud (Terraform Registry)](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/README.md)
- Nodepools:
  - Control planes: 3 × CPX22in `hel1`
  - Worker: 1 × CPX22 in `hel1`

> Note: CPX21 capacity in hel1 caused a Terraform provisioning failure (server_type not available). I switched to CPX22, which solved provisioning.

### 3.2 Outputs

Terraform wrote configs to local files:
```yaml
export KUBECONFIG= ~/sfs-assessment/terraform/kubeconfig
export TALOSCONFIG= ~/sfs-assessment/terraform/talosconfig
```
### 3.3 Verification

 Talos cluster members (etcd on control planes)
 talosctl get member
<img width="1550" height="245" alt="image" src="https://github.com/user-attachments/assets/e5b57db9-d163-4e6b-a803-62bbe86a6a52" />

 Kubernetes nodes
 kubectl get nodes -o wide
 <img width="1550" height="175" alt="image" src="https://github.com/user-attachments/assets/203517ae-3142-4c66-b717-393c94f9494a" />

 kubectl get pods -A
<img width="1361" height="818" alt="image" src="https://github.com/user-attachments/assets/989b087a-efeb-4892-b423-f8b163bac611" />

## 4. GitOps Bootstrap (FluxCD)

Flux was bootstrapped against the GitHub repository:

flux bootstrap github \
  --owner=kalyani-wagadari \
  --repository=talos-gitops \
  --branch=main \
  --path=clusters/production \
  --personal

Verification:

flux get kustomizations -A
kubectl -n flux-system get pods
<img width="1183" height="221" alt="image" src="https://github.com/user-attachments/assets/4f4ee309-0d00-47eb-96be-97c2ae88092d" />


## 5. Cloudflare Tunnel Ingress Controller:

helm repo add strrl.dev https://helm.strrl.dev
helm repo update

helm upgrade --install --wait \
  cloudflare-tunnel-ingress-controller \
  strrl.dev/cloudflare-tunnel-ingress-controller \
  --namespace cloudflare-tunnel-ingress-controller --create-namespace \
  --set cloudflare.apiToken="<CLOUDFLARE_API_TOKEN>" \
  --set cloudflare.accountId="<CLOUDFLARE_ACCOUNT_ID>" \
  --set cloudflare.tunnelName="kalyani-tunnel"

Verification:
kubectl get pods -n cloudflare-tunnel-ingress-controller
<img width="914" height="101" alt="image" src="https://github.com/user-attachments/assets/0e66d766-1a46-4cfd-a9db-39b3e9cd51f4" />

### 5.1. Why Cloudflare Controller Was Installed Manually (Not GitOps):
The Cloudflare Tunnel Ingress Controller requires:
Cloudflare API token
Cloudflare Account ID
The assessment explicitly allows plaintext secrets, but my GitHub repository is public.
To avoid exposing secrets publicly, I installed the controller via Helm manually.

## 6. Application Manifests 
Folder: clusters/production/kalyani-demo/

### 6.1 Namespace


```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kalyani
```


### 6.2 Deployment (EchoServer Application):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: kalyani
spec:
  replicas: 5   # scaled to 5 to demonstrate horizontal scaling
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echoserver
        image: gcr.io/google_containers/echoserver:1.10
        ports:
        - containerPort: 8080
```
        
### 6.3 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: kalyani
spec:
  selector:
    app: echo
  ports:
  - port: 80
    targetPort: 8080
```    
### 6.4 Ingress (Cloudflare Tunnel)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: kalyani
spec:
  ingressClassName: cloudflare-tunnel
  rules:
  - host: kalyani.sfslab.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo
            port:
              number: 80
 ```          
### 6.5 Local Kustomization
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
 ```       
### 6.6 Flux Kustomization 
File: clusters/production/kalyani-demo-kustomization.yaml
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kalyani-demo
  namespace: flux-system
spec:
  interval: 1m
  path: ./clusters/production/kalyani-demo
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
 ```       
Apply via commit & push, then:

flux reconcile kustomization flux-system --with-source (It gets the latest GitHub changes and apply them to the cluster )

kubectl -n kalyani get deploy,svc,ingress

<img width="1483" height="199" alt="image" src="https://github.com/user-attachments/assets/221555ee-3494-4bc6-af4e-caa9662cb2c2" />

### Horizontal Scaling Test
I increased replicas from 1 → 5 in the Deployment manifest.
Flux applied it automatically and Kubernetes distributed pods across nodes.

## 7. Troubleshooting Notes
CPX21 unavailable in hel1 → switched to CPX22
Talos bootstrap delay (nodes were NotReady for ~10 minutes)
Unable to Log In to Initial Hetzner VM - When I created the temporary VM in Hetzner Cloud (required for initial familiarization), the console asked for a password.
Since this was an assessment-provided Hetzner project, I did not know the root password and therefore could not log in.
 **Solution:** Boot Into Hetzner Rescue Mode
Using the Hetzner Cloud Console:

mount /dev/sda1 /mnt
chroot /mnt
Reset the root password
passwd root
Exited chroot and rebooted:
exit
reboot
After this, I could access the server using the new root password.
After logging in, I created my own user so I did not need to work as root.
Commands used:

### Create user
useradd -m kalyani

### Set password
passwd kalyani

### Add user to sudo group (Ubuntu/Debian default)
usermod -aG sudo kalyani

### Switch to the new user
su - kalyani

### Verify groups
groups kalyani

Enabled Rescue Mode.
Rebooted the server.
Switched to Rescue OS console and mounted the actual server disk:

### Decisions Made
Why CPX22: CPX21 unavailable in hel1
Why Echo server: lightweight, stateless, easy to scale
Why Cloudflare Tunnel: no need for LB or public IP, simple DNS
Why GitOps (Flux): declarative mgmt, reproducibility

## 8. What I Learned:
How Talos bootstraps etcd and why control plane nodes take 8–10 minutes to stabilize
How Flux GitRepository + Kustomization interact during reconciliation
How Cloudflare Tunnel simplifies exposure without public IP / LB
How Terraform handles Talos machine config generation
Troubleshooting Hetzner VMs and recovery mode
Importance of separating concerns: GitOps for workloads, Helm for sensitive infra

## 9. What I Would Improve Next

Automate Cloudflare secret injection using Sealed Secrets or SOPS (production scenario)
Add monitoring stack (Prometheus + Grafana)
