output "alb_controller_helm_release_name" {
  description = "The Helm release name for the AWS Load Balancer Controller"
  value       = helm_release.alb_controller.name
}

output "alb_controller_namespace" {
  description = "Namespace where the ALB controller is installed"
  value       = helm_release.alb_controller.namespace
}

output "alb_controller_service_account_name" {
  description = "Name of the service account used by the ALB controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

output "alb_controller_service_account_arn" {
  description = "IAM role ARN assigned to the ALB controller service account"
  value       = var.irsa_role_arn
}

output "alb_dns_name" {
  value = data.aws_lb.alb.dns_name
}

output "alb_zone_id" {
  value = data.aws_lb.alb.zone_id
}