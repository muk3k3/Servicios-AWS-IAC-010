import base64
import binascii
import json

LIMITE_VALOR_BAJO = 5


def handler(event, context):
    alertas = []
    procesados = 0
    invalidos = 0

    for record in event["Records"]:
        try:
            payload = base64.b64decode(record["kinesis"]["data"], validate=True)
            evento = json.loads(payload.decode("utf-8"))
            if not isinstance(evento, dict):
                raise ValueError("el registro JSON no es un objeto")
            procesados += 1
        except (binascii.Error, KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
            invalidos += 1
            print(f"Registro invalido omitido: {error}")
            continue

        valor = evento.get("valor")

        if isinstance(valor, (int, float)) and not isinstance(valor, bool) and valor <= LIMITE_VALOR_BAJO:
            alertas.append(evento)
            print(
                f"ALERTA valor bajo | origen={evento.get('origen')} "
                f"valor={valor}"
            )

    print(
        f"Lambda A proceso {procesados} registros validos, "
        f"omitio {invalidos} invalidos y genero {len(alertas)} alertas de valor bajo"
    )
    return {
        "registros_procesados": procesados,
        "registros_invalidos": invalidos,
        "alertas_generadas": len(alertas),
    }
