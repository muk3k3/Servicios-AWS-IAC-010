import base64
import binascii
import json
import os
import time

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["AUDIT_BUCKET"]


def handler(event, context):
    registros = []
    invalidos = 0

    for record in event["Records"]:
        try:
            payload = base64.b64decode(record["kinesis"]["data"], validate=True)
            venta = json.loads(payload.decode("utf-8"))
            if not isinstance(venta, dict):
                raise ValueError("el registro JSON no es un objeto")
            registros.append(venta)
        except (binascii.Error, KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
            invalidos += 1
            print(f"Registro invalido omitido: {error}")

    key = f"auditoria/{int(time.time() * 1000)}-{context.aws_request_id}.json"
    if registros:
        try:
            s3.put_object(
                Bucket=BUCKET,
                Key=key,
                Body=json.dumps(registros, ensure_ascii=False).encode("utf-8"),
                ContentType="application/json",
            )
        except Exception as error:
            print(f"Error al guardar auditoria en S3: {error}")
            raise

    print(
        f"Consumer B proceso {len(registros)} registros validos, "
        f"omitio {invalidos} invalidos"
    )
    if registros:
        print(f"Auditoria almacenada en s3://{BUCKET}/{key}")

    return {
        "registros_auditados": len(registros),
        "registros_invalidos": invalidos,
    }
