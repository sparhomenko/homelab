terraform {
  required_version = "1.3.5"
  required_providers {
    kubernetes = {
      version = "2.16.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

locals {
  argocd_version = "v2.5.2" # renovate github-releases:argoproj/argo-cd
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
  depends_on = [kubectl_manifest.main["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/appprojects.argoproj.io"]]
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

resource "kubernetes_config_map_v1_data" "main" {
  depends_on = [kubectl_manifest.main["/api/v1/configmaps/argocd-cm"]]
  metadata {
    name      = "argocd-cm"
    namespace = "argocd"
  }
  data = {
    "resource.customizations.health.argoproj.io_Application" = <<-EOT
      hs = {}
      hs.status = "Progressing"
      hs.message = ""
      if obj.status ~= nil then
        if obj.status.health ~= nil then
          hs.status = obj.status.health.status
          if obj.status.health.message ~= nil then
            hs.message = obj.status.health.message
          end
        end
      end
      return hs
    EOT
  }
}

resource "kubernetes_manifest" "app" {
  depends_on = [kubectl_manifest.main["/apis/apiextensions.k8s.io/v1/customresourcedefinitions/applications.argoproj.io"]]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "gitops"
      namespace = kubectl_manifest.project.namespace
    }
    spec = {
      project = kubectl_manifest.project.name
      source = {
        repoURL        = "https://github.com/sparhomenko/homelab.git"
        targetRevision = "HEAD"
        path           = "gitops"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {}
      }
    }
  }
  wait {
    fields = {
      "status.sync.status"                = "Synced"
      "status.health.status"              = "Healthy"
      "status.resources[1].health.status" = "Healthy"
      "status.resources[2].health.status" = "Healthy"
    }
  }
}
