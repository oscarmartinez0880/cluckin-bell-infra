# kubectl Cheat Sheet

- Update kubeconfig (infra/terraform helper targets exist too)
```bash
aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-nonprod --profile cluckin-bell-qa
aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile cluckin-bell-prod
```

- Common checks
```bash
kubectl get nodes
kubectl get pods -A
kubectl get deployments -A
kubectl -n kube-system get pods
```

- Troubleshooting
```bash
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> logs <pod> -c <container>
```
