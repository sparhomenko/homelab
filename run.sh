talosctl cluster destroy
talosctl cluster create \
  --cpus 4 \
  --memory 4096 \
  --install-image ghcr.io/siderolabs/installer:v1.3.0 \
  --kubernetes-version 1.26.0 \
  --workers 0 \
  --config-patch-control-plane '{cluster: {allowSchedulingOnControlPlanes: true}}'

kubectl create namespace argocd
kubectl config set-context --current --namespace=argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.5.5/manifests/core-install.yaml
kubectl wait deployment argocd-repo-server --for condition=Available=True

argocd app create gitops \
  --dest-namespace argocd \
  --dest-server 'https://kubernetes.default.svc' \
  --repo 'https://github.com/sparhomenko/homelab.git' \
  --path gitops \
  --sync-policy auto
argocd app wait gitops
