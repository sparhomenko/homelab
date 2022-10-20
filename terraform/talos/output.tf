locals {
  kube_config = yamldecode(talos_cluster_kubeconfig.main.kube_config)
}

output "host" {
  value = local.kube_config.clusters[0].cluster.server
}

output "client_key" {
  value = base64decode(local.kube_config.users[0].user.client-key-data)
}

output "client_certificate" {
  value = base64decode(local.kube_config.users[0].user.client-certificate-data)
}

output "cluster_ca_certificate" {
  value = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
}
