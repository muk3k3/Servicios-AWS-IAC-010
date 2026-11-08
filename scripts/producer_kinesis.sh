#!/usr/bin/env bash
set -euo pipefail

STREAM_NAME="${1:?Uso: ./producer_kinesis.sh <nombre-del-stream>}"
ORIGENES=("origen-1" "origen-2" "origen-3")
RESULTS_FILE="$(mktemp)"

cleanup() {
  rm -f "$RESULTS_FILE"
}

trap cleanup EXIT

enviar_eventos() {
  local origen="$1"
  local sequence_number
  for _ in $(seq 1 5); do
    local valor=$((RANDOM % 10))
    local payload
    local encoded
    payload=$(printf '{"evento_id":%s,"origen":"%s","valor":%s,"fecha":"%s"}' \
      "$RANDOM" "$origen" "$valor" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    encoded=$(printf '%s\n' "$payload" | base64 --wrap=0)
    sequence_number=$(aws kinesis put-record \
      --stream-name "$STREAM_NAME" \
      --partition-key "$origen" \
      --data "$encoded" \
      --query 'SequenceNumber' \
      --output text \
      --cli-binary-format base64)
    if [[ -z "$sequence_number" || "$sequence_number" == "None" ]]; then
      printf 'Kinesis no devolvio SequenceNumber para %s\n' "$origen" >&2
      return 1
    fi
    printf '%s\t%s\n' "$origen" "$sequence_number" >> "$RESULTS_FILE"
    printf 'Aceptado por Kinesis | origen=%s | SequenceNumber=%s\n' "$origen" "$sequence_number"
    sleep 0.3
  done
}

echo "Enviando eventos simulados de ${#ORIGENES[@]} origenes EN PARALELO a $STREAM_NAME..."
for origen in "${ORIGENES[@]}"; do
  enviar_eventos "$origen" &
done
wait

accepted=$(wc -l < "$RESULTS_FILE")
if [[ "$accepted" -ne 15 ]]; then
  printf 'Error: se esperaban 15 registros aceptados y se confirmaron %s.\n' "$accepted" >&2
  exit 1
fi

printf '\nListo: 15/15 registros aceptados por Kinesis.\n'
printf 'Evidencia a capturar:\n'
printf '  - CloudWatch Logs de la funcion *-lambda-a (alertas filtradas).\n'
printf '  - Bucket de Kinesis (terraform output -raw kinesis_bucket).\n'
printf '  - Consola de Kinesis > Monitoring: IncomingRecords y dos lectores activos.\n'
