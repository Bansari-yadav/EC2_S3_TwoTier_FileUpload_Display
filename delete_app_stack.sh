
#!/bin/bash
set -e
cd "$(dirname "$0")"

set -a
source .env
set +a

export AWS_PAGER=""

echo "== Terminating EC2 instances =="

for APP in uploader viewer; do
  FILE="${APP}_instance_ids.txt"

  if [ -f "$FILE" ]; then
    while read -r ID; do
      [ -z "$ID" ] && continue

      aws ec2 terminate-instances \
        --instance-ids "$ID" \
        --region "$AWS_REGION" >/dev/null

      aws ec2 wait instance-terminated \
        --instance-ids "$ID" \
        --region "$AWS_REGION"
    done < "$FILE"

    rm -f "$FILE"
  fi
done

echo "== Deleting launch templates =="

aws ec2 delete-launch-template \
  --launch-template-name "$UPLOADER_LT_NAME" \
  --region "$AWS_REGION" 2>/dev/null || true

aws ec2 delete-launch-template \
  --launch-template-name "$VIEWER_LT_NAME" \
  --region "$AWS_REGION" 2>/dev/null || true

echo "== Removing IAM roles and profiles =="

for APP in uploader viewer; do

  if [ "$APP" = uploader ]; then
    ROLE="$UPLOADER_ROLE_NAME"
    PROFILE="$UPLOADER_PROFILE_NAME"
  else
    ROLE="$VIEWER_ROLE_NAME"
    PROFILE="$VIEWER_PROFILE_NAME"
  fi

  aws iam remove-role-from-instance-profile \
    --instance-profile-name "$PROFILE" \
    --role-name "$ROLE" 2>/dev/null || true

  aws iam delete-instance-profile \
    --instance-profile-name "$PROFILE" 2>/dev/null || true

  aws iam delete-role-policy \
    --role-name "$ROLE" \
    --policy-name "${ROLE}-policy" 2>/dev/null || true

  aws iam delete-role \
    --role-name "$ROLE" 2>/dev/null || true
done


aws iam delete-role-policy \
  --role-name "$UPLOADER_ROLE_NAME" \
  --policy-name uploader-put-only 2>/dev/null || true

echo "== Deleting S3 bucket =="

aws s3 rm "s3://$BUCKET_NAME" \
  --recursive --region "$AWS_REGION" 2>/dev/null || true

aws s3api delete-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$AWS_REGION" 2>/dev/null || true

echo "Cleanup complete."