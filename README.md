# aws-servicios

Repositorio de evidencia para el curso: despliegue **individual** de **Amazon Kinesis Data
Streams** y **Amazon Data Firehose**, 100% vía IaC (Terraform), con un escenario genérico de
eventos enviados desde distintos orígenes.

## Qué demuestra cada servicio

- **Kinesis Data Streams**: varios orígenes escriben al mismo stream al mismo tiempo, y **dos
  consumidores Lambda leen el mismo stream de forma independiente y en paralelo** (Lambda A
  filtra valores bajos; Lambda B guarda los registros válidos en S3). Esto evidencia la
  característica que Firehose no tiene: múltiples consumidores independientes del mismo flujo.
- **Amazon Data Firehose**: varios orígenes envían eventos, y Firehose los agrupa y entrega
  automáticamente a **un único destino** en S3, sin ninguna lógica de consumo que programar.

## Estructura del repo

```
aws-servicios/
├── README.md                     este archivo
├── .gitignore
├── providers.tf                  versión de Terraform y del provider AWS
├── variables.tf                  variables raíz (region, nombre del proyecto)
├── main.tf                       invoca los dos módulos (kinesis y firehose)
├── outputs.tf                    nombres de stream/bucket para usarlos en los scripts
├── terraform.tfvars.example      copiar a terraform.tfvars y ajustar si hace falta
├── modules/
│   ├── kinesis/
│   │   ├── main.tf               stream, bucket de salida, rol IAM, 2 Lambdas, 2 event source mappings
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── firehose/
│       ├── main.tf               bucket destino, rol IAM, delivery stream
│       ├── variables.tf
│       └── outputs.tf
├── lambdas/
│   ├── lambda_a/
│   │   └── index.py              filtra valores <= 5 y registra alertas
│   └── lambda_b/
│       └── index.py              guarda los registros válidos en S3
├── scripts/
│   ├── producer_kinesis.sh       simula 3 orígenes enviando al stream EN PARALELO
│   └── producer_firehose.sh      simula 2 orígenes enviando al delivery stream
└── build/                        zips generados por Terraform (solo .gitkeep en git)
```

## Cómo desplegar

Desde la raíz del repositorio:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
terraform apply
```

Terraform te mostrará en los outputs el nombre real de los streams, los buckets y las funciones
Lambda.

