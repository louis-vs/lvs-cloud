# Traefik Dashboard

Exposes the Traefik dashboard at <https://traefik.lvs.me.uk> with basic authentication.

## Bootstrap Setup

After Flux is running, create the auth secret:

```bash
# Generate htpasswd hash
HASH=$(htpasswd -nb admin secure-pass)

# Create secret
kubectl create secret generic traefik-dashboard-auth \
  -n kube-system \
  --from-literal=users="$HASH"
```

Change `admin` and `secure-pass` to your desired credentials.
