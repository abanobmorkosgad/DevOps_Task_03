kubectl create namespace argocd   ##create argocd namespace
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml ##install argocd in the cluster
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'  ##make argocd dashboard accessible
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d  ##get argocd password