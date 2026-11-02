#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: bash scripts/publish-processing-image.sh [unique-image-tag]

Requires: Docker running, AWS CLI, Terraform, Python 3, and the Terraform-managed ECR repository.
Builds the linux/arm64 Java Lambda image, pushes to ECR, and writes processing-image.auto.tfvars.json.
Uses AWS_PROFILE (default: pika-ubi). Does not run Terraform apply or update Lambda.
USAGE
  exit 0
fi

if [[ $# -gt 1 ]]; then
  echo '이미지 태그는 하나만 지정하세요.' >&2
  exit 1
fi

ubi_tf_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ubi_image_tag="${1:-java21-$(date -u +%Y%m%dT%H%M%SZ)}"
ubi_aws_profile="${AWS_PROFILE:-pika-ubi}"
if [[ ! "$ubi_image_tag" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]]; then
  echo '올바른 Docker 이미지 태그를 지정하세요.' >&2
  exit 1
fi

for ubi_command in terraform aws docker python3; do
  if ! command -v "$ubi_command" >/dev/null; then
    echo "필요한 프로그램이 없습니다: $ubi_command" >&2
    exit 1
  fi
done
docker info >/dev/null

ubi_repository="$(terraform -chdir="$ubi_tf_dir" output -raw processing_repository_url)"
ubi_repository_name="$(terraform -chdir="$ubi_tf_dir" output -raw processing_repository_name)"
ubi_registry="${ubi_repository%%/*}"
ubi_aws_region="$(printf '%s' "$ubi_registry" | cut -d . -f 4)"

aws --profile "$ubi_aws_profile" --region "$ubi_aws_region" ecr get-login-password \
  | docker login --username AWS --password-stdin "$ubi_registry"

docker buildx build --platform linux/arm64 --provenance=false --push \
  --tag "$ubi_repository:$ubi_image_tag" "$ubi_tf_dir/modules/processing/lambda-java"

ubi_digest="$(aws --profile "$ubi_aws_profile" --region "$ubi_aws_region" ecr describe-images \
  --repository-name "$ubi_repository_name" --image-ids "imageTag=$ubi_image_tag" \
  --query 'imageDetails[0].imageDigest' --output text)"
if [[ ! "$ubi_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo 'ECR에서 올바른 이미지 digest를 확인하지 못했습니다.' >&2
  exit 1
fi

python3 - "$ubi_tf_dir/processing-image.auto.tfvars.json" "$ubi_repository@$ubi_digest" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
config = json.loads(path.read_text()) if path.exists() else {}
config["processing_image_uri"] = sys.argv[2]
path.write_text(json.dumps(config, indent=2) + "\n")
print(f"이미지 업로드 및 주소 저장 완료: {path.name}")
print("새 terraform plan으로 Lambda 교체 범위를 검토하세요. AWS 인프라 적용은 수행하지 않았습니다.")
PY
