#!/bin/bash
set -e

CLUSTER_NAME="my-k8s-cluster"
ROLE_NAME="GHA-EBSCSIDRIVER"
NAMESPACE="kube-system"
SERVICE_ACCOUNT="ebs-csi-controller-sa"

echo "Fetching OIDC provider from cluster..."
OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.identity.oidc.issuer" --output text)

if [[ -z "$OIDC_URL" ]]; then
  echo "OIDC URL not found. Exiting."
  exit 1
fi

OIDC_HOST=$(echo "$OIDC_URL" | cut -d'/' -f3)

OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[*].Arn" \
  --output text | tr '\t' '\n' | grep "$OIDC_HOST")

if [[ -z "$OIDC_PROVIDER_ARN" ]]; then
  echo "OIDC provider ARN not found for host: $OIDC_HOST"
  exit 1
fi

echo "Creating trust policy..."
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_URL#https://}:sub": "system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT"
        }
      }
    }
  ]
}
EOF

echo "Updating IAM role trust relationship..."
aws iam update-assume-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-document file:///tmp/trust-policy.json

echo "Trust policy updated successfully."
