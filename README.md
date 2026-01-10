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
├─ clusters/
│  └─ production/
│     ├─ kalyani-demo/
│     │  ├─ namespace.yaml
│     │  ├─ deployment.yaml
│     │  ├─ service.yaml
│     │  ├─ ingress.yaml
│     │  └─ kustomization.yaml
│     └─ kalyani-demo-kustomization.yaml
└─ screenshots/
├─ terraform/
├─ cluster/
├─ flux/
├─ cloudflare/
├─ app/
└─ scaling/

- `clusters/production/kalyani-demo/` → App manifests and a local `kustomization.yaml`
- `clusters/production/kalyani-demo-kustomization.yaml` → Flux Kustomization CR pointing to the demo folder
- `screenshots/` → Evidence organized per task (Terraform, cluster, Flux, Cloudflare, app, scaling)

---

## 3. Provisioning (Terraform)

> Files kept on the workstation (VM): `~/sfs-assessment/terraform`

### 3.1 Module & Nodepools

- Module used: [hcloud-k8s/kubernetes/hcloud (Terraform Registry)](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/README.md)
- Nodepools:
  - Control planes: 3 × CPX22in `hel1`
  - Worker: 1 × CPX22 in `hel1`

> Note: CPX21 was unavailable in `hel1`; switching to CPX22 ensured provisioning success.

### 3.2 Outputs

Terraform wrote configs to local files:
```yaml
export KUBECONFIG= ~/sfs-assessment/terraform/kubeconfig
export TALOSCONFIG= ~/sfs-assessment/terraform/talosconfig
```
### 3.3 Verification

 Talos cluster members (etcd on control planes)
 talosctl get member

 Kubernetes nodes
 kubectl get nodes -o wide
 kubectl get pods -A

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

flux reconcile kustomization flux-system --with-source

kubectl -n kalyani get deploy,svc,ingress



