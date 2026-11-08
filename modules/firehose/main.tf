data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "destino" {
  bucket        = "${var.project_name}-firehose-destino-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Proyecto = "BembaFarma"
    Servicio = "AmazonDataFirehose"
  }
}

resource "aws_s3_bucket_public_access_block" "destino" {
  bucket = aws_s3_bucket.destino.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "destino" {
  bucket = aws_s3_bucket.destino.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.project_name}-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = aws_s3_bucket.destino.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.destino.arn}/*"
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "ventas_firehose" {
  name        = "${var.project_name}-delivery-ventas"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.destino.arn
    prefix     = "ventas/"

    buffering_size     = 1
    buffering_interval = 60
  }

  tags = {
    Proyecto = "BembaFarma"
    Servicio = "AmazonDataFirehose"
  }
}
