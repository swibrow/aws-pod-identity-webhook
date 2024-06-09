terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "tls_certificate" "kubernetes_oidc_staging" {
  url = "https://raw.githubusercontent.com/swibrow/aws-pod-identity-webhook/main"
}

resource "aws_iam_openid_connect_provider" "kubernetes_oidc_staging" {
  url             = "https://raw.githubusercontent.com/swibrow/aws-pod-identity-webhook/main"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.kubernetes_oidc_staging.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "pitower_test" {
  name = "pitower-test"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : [
            "${aws_iam_openid_connect_provider.kubernetes_oidc_staging.arn}"
          ]
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${aws_iam_openid_connect_provider.kubernetes_oidc_staging.url}:sub" : "system:serviceaccount:test:pitower-test",
            "${aws_iam_openid_connect_provider.kubernetes_oidc_staging.url}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "pitower_test" {
  role       = aws_iam_role.pitower_test.name
  policy_arn = aws_iam_policy.pitower_test.arn
}


resource "aws_iam_policy" "pitower_test" {
  name = "list-buckets"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "s3:ListBucket",
        "Effect" : "Allow",
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}