output "kinesis_stream_name" {
  description = "Nombre del stream de Kinesis Data Streams"
  value       = module.kinesis_demo.stream_name
}

output "kinesis_bucket" {
  description = "Bucket donde la Lambda B guarda los registros validos"
  value       = module.kinesis_demo.bucket_name
}

output "kinesis_lambda_a_function_name" {
  description = "Nombre de la Lambda que genera alertas por valor bajo"
  value       = module.kinesis_demo.lambda_a_function_name
}

output "kinesis_lambda_b_function_name" {
  description = "Nombre de la Lambda que guarda los registros"
  value       = module.kinesis_demo.lambda_b_function_name
}

output "firehose_delivery_stream_name" {
  description = "Nombre del delivery stream de Amazon Data Firehose"
  value       = module.firehose_demo.delivery_stream_name
}

output "firehose_bucket" {
  description = "Bucket destino al que Firehose entrega los datos"
  value       = module.firehose_demo.bucket_name
}
