data "aws_caller_identity" "current" {}

resource "aws_kinesis_stream" "kinesis_stream" {
  name             = "${var.project_name}-kinesis-service"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket" "kinesis_bucket" {
  bucket        = "${var.project_name}-kinesis-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "kinesis_bucket" {
  bucket = aws_s3_bucket.kinesis_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kinesis_bucket" {
  bucket = aws_s3_bucket.kinesis_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_a" {
  name              = "/aws/lambda/${var.project_name}-lambda-a"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_b" {
  name              = "/aws/lambda/${var.project_name}-lambda-b"
  retention_in_days = 7
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.kinesis_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.kinesis_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.lambda_a.arn}:*",
          "${aws_cloudwatch_log_group.lambda_b.arn}:*"
        ]
      }
    ]
  })
}

data "archive_file" "lambda_a_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/lambda_a/index.py"
  output_path = "${path.module}/../../build/lambda_a.zip"
}

data "archive_file" "lambda_b_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/lambda_b/index.py"
  output_path = "${path.module}/../../build/lambda_b.zip"
}

resource "aws_lambda_function" "lambda_a" {
  function_name    = "${var.project_name}-lambda-a"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.14"
  filename         = data.archive_file.lambda_a_zip.output_path
  source_code_hash = data.archive_file.lambda_a_zip.output_base64sha256
  timeout          = 15

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_a
  ]
}

resource "aws_lambda_event_source_mapping" "lambda_a_mapping" {
  event_source_arn  = aws_kinesis_stream.kinesis_stream.arn
  function_name     = aws_lambda_function.lambda_a.arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 10
}

resource "aws_lambda_function" "lambda_b" {
  function_name    = "${var.project_name}-lambda-b"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.14"
  filename         = data.archive_file.lambda_b_zip.output_path
  source_code_hash = data.archive_file.lambda_b_zip.output_base64sha256
  timeout          = 15

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_b
  ]

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.kinesis_bucket.bucket
    }
  }
}

resource "aws_lambda_event_source_mapping" "lambda_b_mapping" {
  event_source_arn  = aws_kinesis_stream.kinesis_stream.arn
  function_name     = aws_lambda_function.lambda_b.arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 10
}
