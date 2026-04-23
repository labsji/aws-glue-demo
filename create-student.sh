#!/bin/bash
set -e

STUDENT_USER="${1:-student007}"
STUDENT_PASS="${2:-Student@GlueLab2026!}"
REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="StudentLearner"
POLICY_NAME="StudentGlueLabPolicy"

echo "=== Creating Student Account ==="
echo "User:    $STUDENT_USER"
echo "Account: $ACCOUNT_ID"
echo ""

# Create user
echo "Creating IAM user..."
aws iam create-user --user-name "$STUDENT_USER" 2>/dev/null || echo "  User already exists"

echo "Setting console password..."
aws iam create-login-profile --user-name "$STUDENT_USER" \
  --password "$STUDENT_PASS" --password-reset-required 2>/dev/null || \
  aws iam update-login-profile --user-name "$STUDENT_USER" --password "$STUDENT_PASS" --password-reset-required

# Inline policy: assume role + cloudshell + change own password
echo "Attaching base user policy..."
aws iam put-user-policy --user-name "$STUDENT_USER" --policy-name StudentBaseAccess \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[
    {\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Resource\":\"arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}\"},
    {\"Effect\":\"Allow\",\"Action\":\"cloudshell:*\",\"Resource\":\"*\"},
    {\"Effect\":\"Allow\",\"Action\":\"iam:ChangePassword\",\"Resource\":\"arn:aws:iam::${ACCOUNT_ID}:user/${STUDENT_USER}\"}
  ]
}"

# Managed policy: scoped lab permissions
LAB_POLICY=$(cat <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"S3BucketManagement",
      "Effect":"Allow",
      "Action":["s3:CreateBucket","s3:DeleteBucket","s3:PutBucketPolicy","s3:GetBucketLocation","s3:ListBucket"],
      "Resource":"arn:aws:s3:::glue-video-*"
    },
    {
      "Sid":"S3ObjectAccess",
      "Effect":"Allow",
      "Action":["s3:GetObject","s3:PutObject","s3:DeleteObject"],
      "Resource":"arn:aws:s3:::glue-video-*/*"
    },
    {
      "Sid":"S3ListAll",
      "Effect":"Allow",
      "Action":"s3:ListAllMyBuckets",
      "Resource":"*"
    },
    {
      "Sid":"GlueJobManagement",
      "Effect":"Allow",
      "Action":["glue:CreateJob","glue:DeleteJob","glue:GetJob","glue:GetJobs","glue:GetJobRun","glue:GetJobRuns","glue:StartJobRun","glue:BatchStopJobRun","glue:UpdateJob"],
      "Resource":"arn:aws:glue:${REGION}:${ACCOUNT_ID}:job/video-frame-*"
    },
    {
      "Sid":"IAMPassRole",
      "Effect":"Allow",
      "Action":"iam:PassRole",
      "Resource":"arn:aws:iam::${ACCOUNT_ID}:role/GlueVideoFrameExtractorRole",
      "Condition":{"StringEquals":{"iam:PassedToService":"glue.amazonaws.com"}}
    },
    {
      "Sid":"IAMRoleManagement",
      "Effect":"Allow",
      "Action":["iam:CreateRole","iam:DeleteRole","iam:PutRolePolicy","iam:DeleteRolePolicy","iam:GetRole","iam:GetRolePolicy"],
      "Resource":"arn:aws:iam::${ACCOUNT_ID}:role/GlueVideoFrameExtractorRole"
    },
    {
      "Sid":"CloudWatchLogs",
      "Effect":"Allow",
      "Action":["logs:GetLogEvents","logs:DescribeLogStreams","logs:DescribeLogGroups"],
      "Resource":"arn:aws:logs:${REGION}:${ACCOUNT_ID}:*"
    },
    {
      "Sid":"CloudShellAccess",
      "Effect":"Allow",
      "Action":"cloudshell:*",
      "Resource":"*"
    },
    {
      "Sid":"STSGetIdentity",
      "Effect":"Allow",
      "Action":"sts:GetCallerIdentity",
      "Resource":"*"
    },
    {
      "Sid":"DenyOtherRegions",
      "Effect":"Deny",
      "Action":["s3:CreateBucket","glue:*"],
      "Resource":"*",
      "Condition":{"StringNotEquals":{"aws:RequestedRegion":"${REGION}"}}
    }
  ]
}
EOF
)

echo "Creating managed lab policy..."
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam create-policy --policy-name "$POLICY_NAME" \
  --policy-document "$LAB_POLICY" \
  --description "Scoped permissions for Glue video processing tutorial" 2>/dev/null || echo "  Policy already exists"

echo "Attaching lab policy to user..."
aws iam attach-user-policy --user-name "$STUDENT_USER" --policy-arn "$POLICY_ARN"

# Create StudentLearner role
echo "Creating StudentLearner role..."
aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document "{
    \"Version\":\"2012-10-17\",
    \"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::${ACCOUNT_ID}:user/${STUDENT_USER}\"},\"Action\":\"sts:AssumeRole\"}]
  }" \
  --description "Role for students doing the Glue video processing tutorial" 2>/dev/null || echo "  Role already exists"

aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" --policy-document "$LAB_POLICY"

echo ""
echo "=== Student Account Ready ==="
echo ""
echo "Console URL: https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "Username:    $STUDENT_USER"
echo "Password:    $STUDENT_PASS  (must change on first login)"
echo "Region:      $REGION (Mumbai)"
echo ""
echo "Student can open CloudShell and run:"
echo "  git clone https://github.com/labsji/aws-glue-demo.git"
echo "  cd aws-glue-demo && chmod +x setup.sh && ./setup.sh"
