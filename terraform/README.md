# Terraform de este práctico — guía de lectura

Este documento recorre el código de `terraform/` pieza por pieza: qué es cada bloque en el
lenguaje de Terraform, para qué sirve aquí concretamente, y cómo se conectan entre sí. Pensado
para explicar el código, no para correrlo (para eso está el `README.md` de la raíz).

---

## 1. El árbol de archivos

```
terraform/
├── versions.tf     # qué Terraform y qué provider necesitamos
├── variables.tf    # "parámetros" del stack (puertos, passwords, nombres)
├── main.tf         # los recursos: red, volúmenes, Postgres, MinIO, MLflow
├── outputs.tf      # qué le mostramos al usuario al final de un apply
├── dev.tfvars      # valores concretos para el ambiente dev
└── prod.tfvars     # valores concretos para el ambiente prod
```

La idea de fondo: **todo lo que hoy es "infraestructura"** (contenedores, redes, volúmenes)
está descripto como código declarativo. No hay `docker run` a mano en ningún lado.

---

## 2. `versions.tf` — qué motor y qué proveedor

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}
```

- `required_providers` le dice a Terraform *qué plugin* necesita para hablar con Docker. Un
  **provider** es lo que traduce bloques HCL en llamadas reales a una API — aquí, a la API de
  Docker (el mismo socket que usa `docker run`).
- `provider "docker" {}` vacío significa "usa la config por defecto del daemon local" (el
  mismo Docker Desktop que ya tienes corriendo).
- Sin este archivo, Terraform no sabría dónde bajar el plugin, ni qué versión.

---

## 3. `variables.tf` — los "parámetros" del stack

```hcl
variable "environment" {
  description = "Nombre del ambiente (dev / prod)"
  type        = string
  default     = "dev"
}

variable "mlflow_port" {
  description = "Puerto host para la UI de MLflow"
  type        = number
  default     = 5000
}
```

Una `variable` es un input configurable: cambia el *valor*, no el *código*. Todo el stack
(nombres de contenedor, puertos, passwords) se arma con interpolaciones de estas variables —
nunca hay un puerto o un nombre "hardcodeado" en `main.tf`. Esto es lo que permite el
TODO 3: el mismo código, con distintos valores de variable, genera un `dev` y un `prod`
aislados.

Observa el flag `sensitive = true` en passwords: no hace que el secreto sea seguro, pero evita
que Terraform lo imprima en el output de `plan`/`apply`.

---

## 4. `dev.tfvars` / `prod.tfvars` — dos "juegos de valores"

```hcl
# dev.tfvars
environment        = "dev"
mlflow_port        = 5000
minio_api_port     = 9000
minio_console_port = 9001
```

```hcl
# prod.tfvars
environment        = "prod"
mlflow_port        = 5001
minio_api_port     = 9010
minio_console_port = 9011
```

Un `.tfvars` es simplemente un archivo que asigna valores a las `variable` declaradas arriba.
`terraform apply -var-file=dev.tfvars` es la forma de decir "usa estos valores". Como los
nombres de recursos y redes incluyen `${var.environment}` (ver más abajo), aplicar con
`dev.tfvars` y con `prod.tfvars` genera **dos stacks completamente independientes** que pueden
convivir en la misma máquina.

---

## 5. `main.tf` — los recursos, uno por uno

### La red

```hcl
resource "docker_network" "mlops" {
  name = "mlops-${var.environment}"
}
```

Un `resource` es la unidad mínima: "quiero que exista esto". El *tipo* (`docker_network`) lo
define el provider; el *nombre local* (`mlops`) es solo una etiqueta para referenciarlo dentro
del código — no es el nombre real del recurso en Docker (ese lo fija el argumento
`name = ...`). Esta red es lo que le permite a los contenedores (Postgres, MinIO, MLflow)
verse entre sí por nombre.

### Los volúmenes

```hcl
resource "docker_volume" "postgres_data" {
  name = "mlops-pg-${var.environment}"
}

resource "docker_volume" "minio_data" {
  name = "mlops-minio-${var.environment}"
}
```

Persistencia: sin esto, cada `terraform apply`/`destroy` perdería los datos de Postgres
(metadata de runs) y de MinIO (artefactos) apenas se recrea el contenedor. El TODO 1 justo
pregunta sobre esto: ¿qué sobrevive a un `destroy` + `apply` y qué no?

### Postgres — backend store de MLflow

```hcl
resource "docker_image" "postgres" {
  name = "postgres:16-alpine"
}

resource "docker_container" "postgres" {
  name  = "postgres-${var.environment}"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_USER=mlflow",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=mlflow"
  ]

  networks_advanced {
    name    = docker_network.mlops.name
    aliases = ["postgres"]
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U mlflow"]
    interval = "5s"
    timeout  = "3s"
    retries  = 5
  }
}
```

Cosas para señalar en clase:

- **`docker_image.postgres.image_id`** — referenciar un atributo de *otro* recurso es cómo
  Terraform arma el grafo de dependencias automáticamente: como este contenedor usa ese
  atributo, Terraform sabe que primero tiene que bajar la imagen, después crear el contenedor.
  Nadie escribió "primero A, después B" — surge solo de la referencia.
- **`aliases = ["postgres"]`** — dentro de la red Docker, cualquier otro contenedor puede
  resolver este servicio por el nombre `postgres` (DNS interno de Docker), sin importar cómo
  se llame el contenedor real (`postgres-dev`, `postgres-prod`, etc.). Por eso el
  `backend-store-uri` de MLflow, más abajo, apunta a `postgres:5432` y no a
  `postgres-dev:5432`.
- **`healthcheck`** — no es una construcción de Terraform, es un argumento que el *provider*
  de Docker expone porque Docker mismo soporta healthchecks. Terraform simplemente lo declara;
  el chequeo real lo corre el daemon de Docker.

### MinIO — artifact store S3-compatible

```hcl
resource "docker_container" "minio" {
  name    = "minio-${var.environment}"
  image   = docker_image.minio.image_id
  command = ["server", "/data", "--console-address", ":9001"]
  ...
  ports {
    internal = 9000
    external = var.minio_api_port
  }
  ports {
    internal = 9001
    external = var.minio_console_port
  }
  ...
}
```

Dos bloques `ports` porque MinIO expone dos cosas distintas: la API S3 (9000, la que usa
MLflow para guardar artefactos) y la consola web (9001, la que abres en el navegador).
`internal` es el puerto *dentro* del contenedor (fijo, lo define la imagen de MinIO);
`external` es el puerto en tu máquina (configurable por variable — así `dev` y `prod` no
pisan el mismo puerto).

### El "job" que crea el bucket

```hcl
resource "docker_container" "create_bucket" {
  name     = "create-bucket-${var.environment}"
  image    = docker_image.mc.image_id
  must_run = false # es un job, no un servicio permanente
  restart  = "no"

  entrypoint = ["/bin/sh", "-c"]
  command = [
    "until mc alias set local http://minio:9000 ${var.minio_root_user} ${var.minio_root_password}; do sleep 2; done && mc mb -p local/${var.artifact_bucket} || true"
  ]

  depends_on = [docker_container.minio]
}
```

`must_run = false` + `restart = "no"` modelan un contenedor que corre una vez y termina (crea
el bucket con `mc mb`) — no un servicio de larga duración. Es la forma declarativa de un "init
job", un patrón común en infra de contenedores. El `until ...; do sleep 2; done` de adentro
existe porque, aunque Terraform ya garantizó que el contenedor de MinIO *existe*
(`depends_on`), no garantiza que el *proceso* adentro ya esté aceptando conexiones — esa
diferencia (existencia vs. disponibilidad) hay que resolverla a mano.

### MLflow — el tracking server

```hcl
resource "docker_image" "mlflow" {
  name = "mlflow-server:local"
  build {
    context    = "${path.module}/../docker"
    dockerfile = "mlflow.Dockerfile"
  }
}

resource "docker_container" "mlflow" {
  name  = "mlflow-${var.environment}"
  image = docker_image.mlflow.image_id

  env = [
    "MLFLOW_S3_ENDPOINT_URL=http://minio:9000",
    "AWS_ACCESS_KEY_ID=${var.minio_root_user}",
    "AWS_SECRET_ACCESS_KEY=${var.minio_root_password}"
  ]

  command = [
    "mlflow", "server",
    "--host", "0.0.0.0",
    "--port", "5000",
    "--backend-store-uri", "postgresql://mlflow:${var.postgres_password}@postgres:5432/mlflow",
    "--artifacts-destination", "s3://${var.artifact_bucket}/",
    "--serve-artifacts"
  ]

  ports {
    internal = 5000
    external = var.mlflow_port
  }

  depends_on = [
    docker_container.postgres,
    docker_container.create_bucket
  ]
}
```

Observa que esta imagen no viene de Docker Hub: `build { context = ..., dockerfile = ... }` le
dice a Terraform que la *construya* localmente a partir de `docker/mlflow.Dockerfile` antes
de poder crear el contenedor. Es la misma idea de "imagen como recurso declarado" que con
Postgres o MinIO, solo que aquí el "de dónde sale la imagen" es un build, no un pull.

El `depends_on` explícito es necesario porque, aunque MLflow *usa* `postgres` y `minio` por
nombre DNS dentro de sus argumentos `command`/`env` (strings, no referencias de Terraform),
Terraform no puede inferir esa dependencia de un string interpolado a mano — hay que
declararla.

---

## 6. `outputs.tf` — la fachada hacia el usuario

```hcl
output "tracking_uri" {
  description = "MLFLOW_TRACKING_URI para el script de training"
  value       = "http://localhost:${var.mlflow_port}"
}
```

Un `output` es lo que ves al correr `terraform output` (o `make output`) después de un
`apply`: la "fachada" pensada para quien usa el stack (URLs a copiar y pegar), no el detalle
de implementación de cómo se armó cada contenedor.

---

## 7. El grafo completo, de un vistazo

```
        docker_network.mlops
                │
    ┌───────────┼───────────────┐
    │           │               │
docker_volume  docker_volume    │
.postgres_data .minio_data      │
    │           │               │
    ▼           ▼               │
docker_container   docker_container
   .postgres          .minio
    │                   │
    │                   ▼
    │           docker_container.create_bucket
    │                   │
    └─────────┬─────────┘
              ▼
     docker_container.mlflow
     (depends_on postgres +
      create_bucket; habla
      con ambos por DNS
      interno de la red)
```

Cada flecha sólida (volúmenes → contenedor, imagen → contenedor) es una dependencia que
Terraform infiere solo de las referencias (`docker_volume.postgres_data.name`,
`docker_image.postgres.image_id`). Las flechas hacia `create_bucket` y `mlflow` incluyen,
además, `depends_on` explícitos porque esas dependencias pasan por strings (URLs, DNS
interno) que Terraform no puede leer automáticamente.

---

## 8. Preguntas para guiar la clase

- ¿Por qué el healthcheck de Postgres no genera, por sí solo, que Terraform *espere* a que
  Postgres esté healthy antes de arrancar MLflow? (Pista: Terraform sabe que el contenedor
  existe, no necesariamente que el proceso adentro ya está listo — mira el `until` del job de
  `create_bucket` para ver cómo se resuelve ese mismo problema a mano.)
- Si cambio `artifact_bucket` en `variables.tf`, ¿qué recursos de `main.tf` se recrean?
  ¿Cuáles no?
- ¿Qué pasa si borro el `depends_on` de `docker_container.mlflow`? ¿Alcanzarían las
  referencias implícitas (imagen, red) para que el orden siga siendo correcto?
- Corriendo `dev.tfvars` y `prod.tfvars` en paralelo (TODO 3): ¿qué recursos son
  *verdaderamente* independientes entre ambos stacks, y cuáles compartirían algo si no fuera
  por `${var.environment}` en cada nombre?
