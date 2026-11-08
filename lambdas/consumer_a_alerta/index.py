import base64
import binascii
import json

UMBRAL_STOCK_CRITICO = 5


def handler(event, context):
    alertas = []
    procesados = 0
    invalidos = 0

    for record in event["Records"]:
        try:
            payload = base64.b64decode(record["kinesis"]["data"], validate=True)
            venta = json.loads(payload.decode("utf-8"))
            if not isinstance(venta, dict):
                raise ValueError("el registro JSON no es un objeto")
            procesados += 1
        except (binascii.Error, KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
            invalidos += 1
            print(f"Registro invalido omitido: {error}")
            continue

        stock_restante = venta.get("stock_restante")

        if isinstance(stock_restante, (int, float)) and not isinstance(stock_restante, bool) and stock_restante <= UMBRAL_STOCK_CRITICO:
            alertas.append(venta)
            print(
                f"ALERTA stock critico | sucursal={venta.get('sucursal')} "
                f"producto={venta.get('producto')} "
                f"stock_restante={stock_restante}"
            )

    print(
        f"Consumer A proceso {procesados} registros validos, "
        f"omitio {invalidos} invalidos y genero {len(alertas)} alertas de stock critico"
    )
    return {
        "registros_procesados": procesados,
        "registros_invalidos": invalidos,
        "alertas_generadas": len(alertas),
    }
