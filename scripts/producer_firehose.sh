#!/usr/bin/env bash
set -euo pipefail

DELIVERY_STREAM="${1:?Uso: ./producer_firehose.sh <nombre-del-delivery-stream>}"
SUCURSALES=("SUC-LIMA01" "SUC-TRUJILLO02")
EXPECTED_RECORDS=$(( ${#SUCURSALES[@]} * 5 ))
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
  --prefix "ventas/" \
  --query 'KeyCount' \
  --output text)
if [[ ! "$baseline_count" =~ ^[0-9]+$ ]]; then
  baseline_count=0
fi

for sucursal in "${SUCURSALES[@]}"; do
  for _ in $(seq 1 5); do
    total=$(printf '%d.90' $(( (RANDOM % 100) + 10 )))
    payload=$(printf '{"venta_id":%s,"sucursal":"%s","producto":"IBUPROFENO-400","total":%s,"fecha":"%s"}' \
      "$RANDOM" "$sucursal" "$total" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    encoded=$(printf '%s\n' "$payload" | base64 --wrap=0)
    record_id=$(aws firehose put-record \
      --delivery-stream-name "$DELIVERY_STREAM" \
      --record "Data=$encoded" \
      --query 'RecordId' \
      --output text \
      --cli-binary-format base64)
    if [[ -z "$record_id" || "$record_id" == "None" ]]; then
      printf 'Firehose no devolvio RecordId para %s.\n' "$sucursal" >&2
      exit 1
    fi
    accepted=$((accepted + 1))
    printf 'Aceptado por Firehose | sucursal=%s | RecordId=%s\n' "$sucursal" "$record_id"
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
    --prefix "ventas/" \
    --query 'KeyCount' \
    --output text)
  if [[ "$object_count" =~ ^[0-9]+$ && "$object_count" -gt "$baseline_count" ]]; then
    printf 'Entrega confirmada: %s objeto(s) bajo ventas/ (antes: %s).\n' "$object_count" "$baseline_count"
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
printf '  - Bucket destino: archivos JSONL bajo ventas/.\n'
