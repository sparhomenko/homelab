terraform {
  required_version = "1.3.3"
  required_providers {
    kubernetes = {
      version = "2.14.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

locals {
  argocd_version = "v2.5.0" # renovate github-releases:argoproj/argo-cd
}

resource "kubernetes_namespace" "main" {
  metadata {
    name = "argocd"
  }
}

data "http" "main" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/${local.argocd_version}/manifests/core-install.yaml"
}

data "kubectl_file_documents" "main" {
  content = data.http.main.response_body
}

# TODO: replace with kubernetes_manifest if this is fixed: https://github.com/hashicorp/terraform-provider-kubernetes/issues/1391
resource "kubectl_manifest" "main" {
  for_each           = data.kubectl_file_documents.main.manifests
  yaml_body          = each.value
  override_namespace = kubernetes_namespace.main.metadata[0].name
}

resource "kubectl_manifest" "project" {
  depends_on = [kubectl_manifest.main]
  yaml_body  = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: default
      namespace: ${kubernetes_namespace.main.metadata[0].name}
    spec:
      clusterResourceWhitelist:
      - group: '*'
        kind: '*'
      destinations:
      - namespace: '*'
        server: '*'
      sourceRepos: ['*']
  EOT
}

resource "kubectl_manifest" "app" {
  yaml_body = <<-EOT
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: gitops
        namespace: ${kubectl_manifest.project.namespace}
      spec:
        project: ${kubectl_manifest.project.name}
        source:
          repoURL: https://github.com/sparhomenko/homelab.git
          targetRevision: HEAD
          path: gitops
        destination:
          server: https://kubernetes.default.svc
  EOT
}
