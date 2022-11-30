terraform {
  required_version = "1.3.6"
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.1.0-alpha.10"
    }
  }
}

resource "talos_machine_secrets" "main" {}

resource "talos_machine_configuration_controlplane" "main" {
  cluster_name       = "HomeLab"
  cluster_endpoint   = "https://${var.nodes[0]}:6443"
  machine_secrets    = talos_machine_secrets.main.machine_secrets
  docs_enabled       = false
  examples_enabled   = false
  kubernetes_version = "1.25.4" # renovate github-releases:kubernetes/kubernetes:^v(?<version>.*)$
}

resource "talos_client_configuration" "main" {
  cluster_name    = talos_machine_configuration_controlplane.main.cluster_name
  machine_secrets = talos_machine_secrets.main.machine_secrets
  endpoints       = var.nodes
}

resource "talos_machine_configuration_apply" "main" {
  for_each              = toset(var.nodes)
  talos_config          = talos_client_configuration.main.talos_config
  machine_configuration = talos_machine_configuration_controlplane.main.machine_config
  endpoint              = each.key
  node                  = each.key
  config_patches = [yamlencode({
    machine : { certSANs : var.nodes }
    cluster : { allowSchedulingOnControlPlanes : true }
  })]
}

resource "talos_machine_bootstrap" "main" {
  depends_on   = [talos_machine_configuration_apply.main]
  talos_config = talos_client_configuration.main.talos_config
  endpoint     = var.nodes[0]
  node         = var.nodes[0]
  provisioner "local-exec" {
    command = "until nc -z ${var.nodes[0]} 6443; do echo Waiting for API server...; sleep 1; done"
  }
}

resource "talos_cluster_kubeconfig" "main" {
  talos_config = talos_client_configuration.main.talos_config
  endpoint     = talos_machine_bootstrap.main.endpoint
  node         = talos_machine_bootstrap.main.node
}

resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.main.kube_config
  filename        = "kubeconfig"
  file_permission = "0600"
}
