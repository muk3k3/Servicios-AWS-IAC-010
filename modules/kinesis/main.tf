data "aws_caller_identity" "current" {}

resource "aws_kinesis_stream" "ventas_stream" {
  name             = "${var.project_name}-stream-ventas-kardex"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Proyecto = "BembaFarma"
    Servicio = "KinesisDataStreams"
  }
}

resource "aws_s3_bucket" "auditoria" {
  bucket        = "${var.project_name}-auditoria-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Proyecto = "BembaFarma"
    Servicio = "KinesisDataStreams"
  }
}

resource "aws_s3_bucket_public_access_block" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "auditoria" {
  bucket = aws_s3_bucket.auditoria.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudwatch_log_group" "consumer_a" {
  name              = "/aws/lambda/${var.project_name}-consumer-a-alerta"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "consumer_b" {
  name              = "/aws/lambda/${var.project_name}-consumer-b-auditoria"
  retention_in_days = 7
}

resource "aws_iam_role" "lambda_consumers_role" {
  name = "${var.project_name}-lambda-consumers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_consumers_policy" {
  name = "${var.project_name}-lambda-consumers-policy"
  role = aws_iam_role.lambda_consumers_role.id

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
        Resource = aws_kinesis_stream.ventas_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.auditoria.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.consumer_a.arn}:*",
          "${aws_cloudwatch_log_group.consumer_b.arn}:*"
        ]
      }
    ]
  })
}

data "archive_file" "consumer_a_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/consumer_a_alerta/index.py"
  output_path = "${path.module}/../../build/consumer_a_alerta.zip"
}

data "archive_file" "consumer_b_zip" {
  type        = "zip"
  source_file = "${path.module}/../../lambdas/consumer_b_auditoria/index.py"
  output_path = "${path.module}/../../build/consumer_b_auditoria.zip"
}

resource "aws_lambda_function" "consumer_a" {
  function_name    = "${var.project_name}-consumer-a-alerta"
  role             = aws_iam_role.lambda_consumers_role.arn
  handler          = "index.handler"
  runtime          = "python3.14"
  filename         = data.archive_file.consumer_a_zip.output_path
  source_code_hash = data.archive_file.consumer_a_zip.output_base64sha256
  timeout          = 15

  depends_on = [
    aws_iam_role_policy.lambda_consumers_policy,
    aws_cloudwatch_log_group.consumer_a
  ]
}

resource "aws_lambda_event_source_mapping" "consumer_a_mapping" {
  event_source_arn  = aws_kinesis_stream.ventas_stream.arn
  function_name     = aws_lambda_function.consumer_a.arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 10
}

resource "aws_lambda_function" "consumer_b" {
  function_name    = "${var.project_name}-consumer-b-auditoria"
  role             = aws_iam_role.lambda_consumers_role.arn
  handler          = "index.handler"
  runtime          = "python3.14"
  filename         = data.archive_file.consumer_b_zip.output_path
  source_code_hash = data.archive_file.consumer_b_zip.output_base64sha256
  timeout          = 15

  depends_on = [
    aws_iam_role_policy.lambda_consumers_policy,
    aws_cloudwatch_log_group.consumer_b
  ]

  environment {
    variables = {
      AUDIT_BUCKET = aws_s3_bucket.auditoria.bucket
    }
  }
}

resource "aws_lambda_event_source_mapping" "consumer_b_mapping" {
  event_source_arn  = aws_kinesis_stream.ventas_stream.arn
  function_name     = aws_lambda_function.consumer_b.arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 10
}
