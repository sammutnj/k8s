#!/usr/bin/env bash

set -e

CLUSTER_NAME="my-k8s-cluster"
ROLE_NAME="GHA-EBSCSIDRIVER"
NAMESPACE="kube-system"
SERVICE_ACCOUNT="ebs-csi-controller-sa"

echo "Fetching OIDC provider from cluster..."
OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.identity.oidc.issuer" --output text)

OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[*].Arn" --output text | tr '\t' '\n' | grep "$(echo $OIDC_URL | cut -d'/' -f3)")

echo "Creating trust policy..."
read -r -d '' TRUST_POLICY <<EOF
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
          "$(echo $OIDC_URL | sed 's|https://||'):sub": "system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT"
        }
      }
    }
  ]
}
EOF

echo "Updating IAM role trust relationship..."
aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST_POLICY"
