set -e

talosctl cluster destroy
talosctl cluster create \
  --cpus 4 \
  --memory 4096 \
  --kubernetes-version 1.26.0 \
  --workers 0 \
  --config-patch-control-plane '{cluster: {allowSchedulingOnControlPlanes: true}}'

kubectl apply -k argocd/
kubectl apply -f gitops.yaml
kubectl config set-context --current --namespace=argocd
kubectl create secret generic argocd-vault-plugin-google-credentials --from-file=google-credentials.json
kubectl wait deployment argocd-repo-server --for condition=Available=True --timeout=60s
kubectl wait app gitops --for jsonpath='{.status.sync.status}'=Synced --timeout=180s
