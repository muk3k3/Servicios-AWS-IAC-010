output "stream_name" {
  value = aws_kinesis_stream.kinesis_stream.name
}

output "bucket_name" {
  value = aws_s3_bucket.kinesis_bucket.bucket
}

output "lambda_a_function_name" {
  value = aws_lambda_function.lambda_a.function_name
}

output "lambda_b_function_name" {
  value = aws_lambda_function.lambda_b.function_name
}
