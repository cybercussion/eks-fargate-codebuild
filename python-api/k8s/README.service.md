
# Overview

This file explains the purpose and configuration of the Kubernetes Service defined in service.yaml.
It helps clarify when and why to use `type: ClusterIP` vs `LoadBalancer` and how this connects with Ingress.

## Service Types

### 1. ClusterIP (default)

- Accessible only from inside the cluster (internal traffic)
- Used with Ingress controllers (e.g., ALB Ingress) for HTTP routing
- Recommended for most web apps/APIs when using an Ingress

### 2. LoadBalancer

- Exposes the service via an external load balancer provisioned by the cloud provider (e.g., NLB in AWS)
- Ideal when you want direct external access to a TCP or HTTP service **without** using Ingress
- Not suited for host/path routing — use Ingress for that

### 3. NodePort

- Exposes service on a static port across all nodes
- Often used with an external LB or for dev/testing

## Example Use Cases

### ClusterIP + Ingress (recommended for ALB)

```yaml
   kind: Service
   metadata:
     name: python-api
   spec:
     type: ClusterIP
     ports:
       - port: 80
         targetPort: 80
     selector:
       app: python-api
```

### With a matching Ingress (using ALB)

- ALB terminates TLS (via ACM)
- Routes traffic to ClusterIP service
- Pods receive traffic directly (via IP target type)

### LoadBalancer (no Ingress)

```yaml
   kind: Service
   metadata:
     name: python-api
   spec:
     type: LoadBalancer
     ports:
       - port: 80
         targetPort: 80
     selector:
       app: python-api
```

AWS will provision an NLB by default (or ALB if using AWS Load Balancer Controller with annotations)
Suitable for TCP-based apps or gRPC APIs where path-based routing isn't needed

### Summary

- Use ClusterIP with Ingress for full-featured HTTP routing (preferred for microservices/web APIs)
- Use LoadBalancer only if you want raw access without an Ingress
- Always align your service `type` with your networking strategy (ALB/NLB)

For HTTP-based apps, the best setup is:

→ [Internet] → [ALB Ingress] → [ClusterIP Service] → [Pod]
