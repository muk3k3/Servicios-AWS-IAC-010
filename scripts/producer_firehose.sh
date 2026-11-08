#!/usr/bin/env bash
set -euo pipefail

DELIVERY_STREAM="${1:?Uso: ./producer_firehose.sh <nombre-del-delivery-stream>}"
ORIGENES=("origen-1" "origen-2")
EXPECTED_RECORDS=$(( ${#ORIGENES[@]} * 5 ))
accepted=0

bucket_arn=$(aws firehose describe-delivery-stream \
  --delivery-stream-name "$DELIVERY_STREAM" \
  --query 'DeliveryStreamDescription.Destinations[0].ExtendedS3DestinationDescription.BucketARN' \
  --output text)
bucket_name="${bucket_arn##*:}"
if [[ -z "$bucket_name" || "$bucket_name" == "None" ]]; then
  printf 'Error: no se pudo obtener el bucket S3 del delivery stream.\n' >&2
  exit 1
fi

baseline_count=$(aws s3api list-objects-v2 \
  --bucket "$bucket_name" \
  --prefix "records/" \
  --query 'KeyCount' \
  --output text)
if [[ ! "$baseline_count" =~ ^[0-9]+$ ]]; then
  baseline_count=0
fi

for origen in "${ORIGENES[@]}"; do
  for _ in $(seq 1 5); do
    valor=$(printf '%d.90' $(( (RANDOM % 100) + 10 )))
    payload=$(printf '{"evento_id":%s,"origen":"%s","valor":%s,"fecha":"%s"}' \
      "$RANDOM" "$origen" "$valor" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    encoded=$(printf '%s\n' "$payload" | base64 --wrap=0)
    record_id=$(aws firehose put-record \
      --delivery-stream-name "$DELIVERY_STREAM" \
      --record "Data=$encoded" \
      --query 'RecordId' \
      --output text \
      --cli-binary-format base64)
    if [[ -z "$record_id" || "$record_id" == "None" ]]; then
      printf 'Firehose no devolvio RecordId para %s.\n' "$origen" >&2
      exit 1
    fi
    accepted=$((accepted + 1))
    printf 'Aceptado por Firehose | origen=%s | RecordId=%s\n' "$origen" "$record_id"
  done
done

if [[ "$accepted" -ne "$EXPECTED_RECORDS" ]]; then
  printf 'Error: se esperaban %s registros aceptados y se confirmaron %s.\n' "$EXPECTED_RECORDS" "$accepted" >&2
  exit 1
fi

printf '\nSe enviaron %s/%s registros. Esperando entrega en S3...\n' "$accepted" "$EXPECTED_RECORDS"
printf 'Bucket destino: %s\n' "$bucket_name"

max_attempts=36
for attempt in $(seq 1 "$max_attempts"); do
  object_count=$(aws s3api list-objects-v2 \
    --bucket "$bucket_name" \
    --prefix "records/" \
    --query 'KeyCount' \
    --output text)
  if [[ "$object_count" =~ ^[0-9]+$ && "$object_count" -gt "$baseline_count" ]]; then
    printf 'Entrega confirmada: %s objeto(s) bajo records/ (antes: %s).\n' "$object_count" "$baseline_count"
    break
  fi

  if [[ "$attempt" -eq "$max_attempts" ]]; then
    printf 'Error: no se detecto un objeto nuevo en S3 despues de %s segundos.\n' "$((max_attempts * 5))" >&2
    exit 1
  fi

  printf 'Intento %s/%s: aun no hay objetos nuevos. Reintentando en 5 segundos...\n' "$attempt" "$max_attempts"
  sleep 5
done

printf 'Evidencia a capturar:\n'
printf '  - Consola de Firehose > Monitoring: IncomingRecords y DeliveryToS3.Success.\n'
printf '  - Bucket destino: archivos JSONL bajo records/.\n'
