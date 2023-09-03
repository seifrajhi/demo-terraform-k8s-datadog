
data "tfe_outputs" "eks" {
  organization = var.tfc_org
  workspace = var.tfc_workspace
}
data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../demo-terraform-eks-datadog/terraform.tfstate"
  }
}



# Retrieve EKS cluster configuration
data "aws_eks_cluster" "cluster" {

  name = data.terraform_remote_state.eks.outputs.cluster_name
 

}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_deployment" "demo" {
  metadata {
    name      = var.application_name
    namespace = kubernetes_namespace.demo.id
    labels = {
      app = var.application_name
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = var.application_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.application_name
        }
      }

      spec {
        container {
          image = "rajhisaifeddine/demo:datadog"
          name  = var.application_name
        }
      }
    }
  }
}

resource "kubernetes_service" "demo" {
  metadata {
    name      = var.application_name
    namespace = kubernetes_namespace.demo.id
  }
  spec {
    selector = {
      app = kubernetes_deployment.demo.metadata[0].labels.app
    }
    port {
      port        = 8080
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

output "demo_endpoint" {
  value = "${kubernetes_service.demo.status[0].load_balancer[0].ingress[0].hostname}:8080"
}
