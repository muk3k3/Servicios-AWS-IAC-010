output "kinesis_stream_name" {
  description = "Nombre del stream de Kinesis Data Streams"
  value       = module.kinesis_demo.stream_name
}

output "kinesis_audit_bucket" {
  description = "Bucket donde el Consumer B copia los registros validos (auditoria)"
  value       = module.kinesis_demo.audit_bucket_name
}

output "kinesis_consumer_a_function_name" {
  description = "Nombre de la Lambda que genera alertas de stock"
  value       = module.kinesis_demo.consumer_a_function_name
}

output "kinesis_consumer_b_function_name" {
  description = "Nombre de la Lambda que guarda la auditoria"
  value       = module.kinesis_demo.consumer_b_function_name
}

output "firehose_delivery_stream_name" {
  description = "Nombre del delivery stream de Amazon Data Firehose"
  value       = module.firehose_demo.delivery_stream_name
}

output "firehose_destination_bucket" {
  description = "Bucket destino al que Firehose entrega los datos"
  value       = module.firehose_demo.destination_bucket_name
}
