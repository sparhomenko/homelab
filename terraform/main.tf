terraform {
  required_version = "1.3.6"
  required_providers {
    local = {
      version = "2.2.3"
    }
    kubernetes = {
      version = "2.16.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.1.0-alpha.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "talos" {}

module "talos" {
  source = "./talos"
  nodes  = var.nodes
}

provider "kubernetes" {
  host                   = module.talos.host
  client_key             = module.talos.client_key
  client_certificate     = module.talos.client_certificate
  cluster_ca_certificate = module.talos.cluster_ca_certificate
}

provider "kubectl" {
  host                   = module.talos.host
  client_key             = module.talos.client_key
  client_certificate     = module.talos.client_certificate
  cluster_ca_certificate = module.talos.cluster_ca_certificate
  load_config_file       = false
}

module "argocd" {
  source = "./argocd"
}
