output "delivery_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.ventas_firehose.name
}

output "destination_bucket_name" {
  value = aws_s3_bucket.destino.bucket
}
