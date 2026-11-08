#!/usr/bin/env bash
set -euo pipefail

STREAM_NAME="${1:?Uso: ./producer_kinesis.sh <nombre-del-stream>}"
SUCURSALES=("SUC-LIMA01" "SUC-TRUJILLO02" "SUC-AREQUIPA03")
RESULTS_FILE="$(mktemp)"

cleanup() {
  rm -f "$RESULTS_FILE"
}

trap cleanup EXIT

enviar_eventos() {
  local sucursal="$1"
  local sequence_number
  for _ in $(seq 1 5); do
    local stock=$((RANDOM % 10))
    local payload
    local encoded
    payload=$(printf '{"venta_id":%s,"sucursal":"%s","producto":"PARACETAMOL-500","stock_restante":%s,"fecha":"%s"}' \
      "$RANDOM" "$sucursal" "$stock" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    encoded=$(printf '%s\n' "$payload" | base64 --wrap=0)
    sequence_number=$(aws kinesis put-record \
      --stream-name "$STREAM_NAME" \
      --partition-key "$sucursal" \
      --data "$encoded" \
      --query 'SequenceNumber' \
      --output text \
      --cli-binary-format base64)
    if [[ -z "$sequence_number" || "$sequence_number" == "None" ]]; then
      printf 'Kinesis no devolvio SequenceNumber para %s\n' "$sucursal" >&2
      return 1
    fi
    printf '%s\t%s\n' "$sucursal" "$sequence_number" >> "$RESULTS_FILE"
    printf 'Aceptado por Kinesis | sucursal=%s | SequenceNumber=%s\n' "$sucursal" "$sequence_number"
    sleep 0.3
  done
}

echo "Enviando eventos simulados de ${#SUCURSALES[@]} sucursales EN PARALELO a $STREAM_NAME..."
for sucursal in "${SUCURSALES[@]}"; do
  enviar_eventos "$sucursal" &
done
wait

accepted=$(wc -l < "$RESULTS_FILE")
if [[ "$accepted" -ne 15 ]]; then
  printf 'Error: se esperaban 15 registros aceptados y se confirmaron %s.\n' "$accepted" >&2
  exit 1
fi

printf '\nListo: 15/15 registros aceptados por Kinesis.\n'
printf 'Evidencia a capturar:\n'
printf '  - CloudWatch Logs de la funcion *-consumer-a-alerta (alertas filtradas).\n'
printf '  - Bucket de auditoria (terraform output -raw kinesis_audit_bucket).\n'
printf '  - Consola de Kinesis > Monitoring: IncomingRecords y dos lectores activos.\n'
