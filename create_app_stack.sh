
#!/bin/bash
set -e

cd "$(dirname "$0")"
set -a
source .env
set +a
export AWS_PAGER=""

echo "== Checking configuration =="

for VAR in AWS_REGION AMI_ID INSTANCE_TYPE KEY_NAME BUCKET_NAME APP_SECURITY_GROUP_ID UPLOADER_ROLE_NAME UPLOADER_PROFILE_NAME UPLOADER_LT_NAME VIEWER_ROLE_NAME VIEWER_PROFILE_NAME VIEWER_LT_NAME; do
  if [ -z "${!VAR}" ] || [[ "${!VAR}" == YOUR_* ]]; then
    echo "Missing configuration: $VAR"
    exit 1
  fi
done

echo "== Creating S3 bucket =="

if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
  echo "S3 bucket already exists."
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

echo "== Configuring IAM roles =="

cat > trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

for ROLE in "$UPLOADER_ROLE_NAME" "$VIEWER_ROLE_NAME"; do
  if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
    aws iam create-role \
      --role-name "$ROLE" \
      --assume-role-policy-document file://trust-policy.json >/dev/null
  fi
done

cat > uploader-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject"],
    "Resource": "arn:aws:s3:::${BUCKET_NAME}/shared.txt"
  }]
}
EOF

cat > viewer-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/shared.txt"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$UPLOADER_ROLE_NAME" \
  --policy-name "${UPLOADER_ROLE_NAME}-policy" \
  --policy-document file://uploader-policy.json

aws iam put-role-policy \
  --role-name "$VIEWER_ROLE_NAME" \
  --policy-name "${VIEWER_ROLE_NAME}-policy" \
  --policy-document file://viewer-policy.json

for APP in uploader viewer; do

  if [ "$APP" = uploader ]; then
    ROLE="$UPLOADER_ROLE_NAME"
    PROFILE="$UPLOADER_PROFILE_NAME"
  else
    ROLE="$VIEWER_ROLE_NAME"
    PROFILE="$VIEWER_PROFILE_NAME"
  fi

  if ! aws iam get-instance-profile \
    --instance-profile-name "$PROFILE" >/dev/null 2>&1; then

    aws iam create-instance-profile \
      --instance-profile-name "$PROFILE" >/dev/null
  fi

  EXISTING_ROLE=$(aws iam get-instance-profile \
    --instance-profile-name "$PROFILE" \
    --query "InstanceProfile.Roles[].RoleName" \
    --output text)

  if [ "$EXISTING_ROLE" != "$ROLE" ]; then
    aws iam add-role-to-instance-profile \
      --instance-profile-name "$PROFILE" \
      --role-name "$ROLE"
  fi
done

echo "Waiting for IAM propagation..."
sleep 20

echo "== Building user-data and launch templates =="

for APP in uploader viewer; do

  APP_JS_B64=$(base64 -w0 "lab03/${APP}-app/app.js")
  PKG_JSON_B64=$(base64 -w0 "lab03/${APP}-app/package.json")

  if [ "$APP" = uploader ]; then
    PROFILE="$UPLOADER_PROFILE_NAME"
    LT="$UPLOADER_LT_NAME"
  else
    PROFILE="$VIEWER_PROFILE_NAME"
    LT="$VIEWER_LT_NAME"
  fi

  cat > "user-data-${APP}.sh" <<EOF
#!/bin/bash
set -e
dnf install -y nodejs

mkdir -p /opt/app
echo "$APP_JS_B64" | base64 -d > /opt/app/app.js
echo "$PKG_JSON_B64" | base64 -d > /opt/app/package.json

cd /opt/app
npm install --omit=dev

cat > /etc/systemd/system/${APP}.service <<'SERVICE'
[Unit]
Description=${APP} Application
After=network-online.target
Wants=network-online.target

[Service]
Environment=BUCKET_NAME=$BUCKET_NAME
Environment=AWS_REGION=$AWS_REGION
Environment=PORT=3000
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node /opt/app/app.js
Restart=always
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

chown -R ec2-user:ec2-user /opt/app
systemctl daemon-reload
systemctl enable ${APP}.service
systemctl start ${APP}.service
EOF

  USERDATA_B64=$(base64 -w0 "user-data-${APP}.sh")

  cat > "${APP}-lt-data.json" <<EOF
{
  "ImageId": "$AMI_ID",
  "InstanceType": "$INSTANCE_TYPE",
  "KeyName": "$KEY_NAME",
  "SecurityGroupIds": ["$APP_SECURITY_GROUP_ID"],
  "IamInstanceProfile": {
    "Name": "$PROFILE"
  },
  "UserData": "$USERDATA_B64",
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "${APP}-app"}
      ]
    }
  ]
}
EOF

  echo "Configuring launch template: $LT"

  if aws ec2 describe-launch-templates \
    --launch-template-names "$LT" \
    --region "$AWS_REGION" >/dev/null 2>&1; then

    aws ec2 create-launch-template-version \
      --launch-template-name "$LT" \
      --launch-template-data "file://${APP}-lt-data.json" \
      --region "$AWS_REGION" >/dev/null

  else

    aws ec2 create-launch-template \
      --launch-template-name "$LT" \
      --launch-template-data "file://${APP}-lt-data.json" \
      --region "$AWS_REGION" >/dev/null
  fi
done

echo "== Launching EC2 instances =="

for APP in uploader viewer; do

  if [ "$APP" = uploader ]; then
    LT="$UPLOADER_LT_NAME"
  else
    LT="$VIEWER_LT_NAME"
  fi

  INSTANCE_ID=$(aws ec2 run-instances \
    --launch-template "LaunchTemplateName=$LT,Version=\$Latest" \
    --count 1 \
    --region "$AWS_REGION" \
    --query "Instances[0].InstanceId" \
    --output text)

  echo "$INSTANCE_ID" >> "${APP}_instance_ids.txt"
  echo "$APP instance: $INSTANCE_ID"
done

echo "Waiting for instances to run..."

INSTANCE_IDS=$(cat uploader_instance_ids.txt viewer_instance_ids.txt)

aws ec2 wait instance-running \
  --instance-ids $INSTANCE_IDS \
  --region "$AWS_REGION"

echo "== Instance public IP addresses =="

aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --region "$AWS_REGION" \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],PublicIpAddress]" \
  --output table

echo "Deployment completed."
echo "Wait 60-90 seconds before opening the websites."