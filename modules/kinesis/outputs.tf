output "stream_name" {
  value = aws_kinesis_stream.ventas_stream.name
}

output "audit_bucket_name" {
  value = aws_s3_bucket.auditoria.bucket
}

output "consumer_a_function_name" {
  value = aws_lambda_function.consumer_a.function_name
}

output "consumer_b_function_name" {
  value = aws_lambda_function.consumer_b.function_name
}
