terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }
  }

  backend "s3" {}
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}
# Fetch domain from SSM
data "aws_ssm_parameter" "domain" {
  name = var.ssm_domain_param
}
# Fetch Certificate ARN from SSM
data "aws_ssm_parameter" "certificate" {
  name = var.certificate_ssm_path
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = can(base64decode(var.cluster_ca)) ? base64decode(var.cluster_ca) : ""
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = can(base64decode(var.cluster_ca)) ? base64decode(var.cluster_ca) : ""
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "time_sleep" "wait_for_alb" {
  depends_on = [kubernetes_ingress_v1.ingress]
  create_duration = "30s"
}

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }
}

resource "helm_release" "alb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  version          = var.chart_version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
}

# Data source to fetch the ALB after it's created
data "aws_lb" "alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack" = "default/${var.service_name}-ingress"
  }
  depends_on = [time_sleep.wait_for_alb]
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name      = "${var.service_name}-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                   = "alb"  # Use AWS ALB controller
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"  # Change to "internal" if you need it
      "alb.ingress.kubernetes.io/certificate-arn"      = data.aws_ssm_parameter.certificate.value  # ACM Certificate ARN
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"  # Define ports
      "alb.ingress.kubernetes.io/target-type"          = "ip"  # IP-based targeting
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/health"  # Health check path
    }
  }

  spec {
    rule {
      host = "${var.service_name}-${var.env}.${data.aws_ssm_parameter.domain.value}"

      http {
        path {
          path = "/"
          backend {
            service {
              name = var.service_name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.alb_controller] # Ensure the ALB controller is deployed before creating the ingress
}

# Possible workaround for finalizer issue
# resource "null_resource" "patch_ingress_finalizer" {
#   provisioner "local-exec" {
#     when    = destroy
#     command = "kubectl patch ingress ${var.service_name}-ingress -n default -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge"
#   }

#   depends_on = [kubernetes_ingress_v1.ingress]
# }