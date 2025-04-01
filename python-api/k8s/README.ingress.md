# Why use an ALB vs NLB in Kubernetes Ingress

## ALB (Application Load Balancer)

- Layer 7 (HTTP/HTTPS): Supports host/path-based routing, perfect for APIs and web apps.
- Integrates with AWS Load Balancer Controller using `ingressClassName: alb`.
- Supports SSL termination (via ACM) and can route multiple domains/paths through one LB.
- Works best for microservices needing routing logic at the application layer.
- Target type "ip" allows ALB to route directly to pod IPs (great for Fargate or non-NodePort setups).

## NLB (Network Load Balancer)

- Layer 4 (TCP/UDP): Used for raw performance, static IPs, or non-HTTP protocols.
- Lower latency and higher throughput, ideal for things like gRPC, WebSocket, or custom TCP.
- Cannot perform HTTP routing — not suitable for Ingress-style traffic control.
- Typically used via `Service.Type=LoadBalancer` (See `service.yaml`) rather than Ingress.

## In this case, ALB is used to

- Route traffic to a Kubernetes service (`python-api`)
- Handle TLS (via ACM cert)
- Support clean HTTPS + custom domain (via Route53)
- Provide path-based routing if needed later (e.g., /api, /admin)
