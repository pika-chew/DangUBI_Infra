resource "aws_ecr_repository" "preprocess" {
  name                 = "${var.name_prefix}-preprocess"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "preprocess" {
  repository = aws_ecr_repository.preprocess.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaImageRetrieval"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${local.function_name}"
        }
      }
    }]
  })
}
