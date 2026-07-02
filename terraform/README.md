# Terraform de este práctico — guía de lectura

Este documento recorre el código de `terraform/` pieza por pieza: qué es cada bloque en el
lenguaje de Terraform, para qué sirve aquí concretamente, y cómo se conectan entre sí. Pensado
para explicar el código, no para correrlo (para eso está el `README.md` de la raíz).

---

## 1. El árbol de archivos

```
terraform/
├── versions.tf          # qué Terraform y qué provider necesitamos
├── variables.tf         # "parámetros" del stack (puertos, passwords, nombres)
├── main.tf              # arma el stack invocando módulos
├── outputs.tf           # qué le mostramos al usuario al final de un apply
├── dev.tfvars           # valores concretos para el ambiente dev
├── prod.tfvars          # valores concretos para el ambiente prod
└── modules/
    ├── storage/         # Postgres + MinIO + bucket
    ├── mlflow/          # el tracking server
    └── serving/         # (TODO 5) sirve un modelo registrado
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
nunca hay un puerto o un nombre "hardcodeado" en los módulos. Esto es lo que permite el
TODO 3: el mismo código, con distintos valores de variable y distinto workspace de Terraform,
genera un `dev` y un `prod` aislados.

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
serving_port       = 5002
```

```hcl
# prod.tfvars
environment        = "prod"
mlflow_port        = 5001
minio_api_port     = 9010
minio_console_port = 9011
serving_port       = 5012
```

Un `.tfvars` es simplemente un archivo que asigna valores a las `variable` declaradas arriba.
`terraform apply -var-file=dev.tfvars` es la forma de decir "usá estos valores".

Ojo: un `.tfvars` no crea un state separado. Si aplicas `dev.tfvars` y después `prod.tfvars`
en el mismo workspace, Terraform interpreta que quieres cambiar el mismo stack de dev a prod.
Por eso el práctico usa workspaces: `dev` vive en el workspace `default` y `prod` vive en el
workspace `prod`.

---

## 5. `main.tf` raíz — orquesta módulos, no recursos

```hcl
resource "terraform_data" "environment_guard" {
  ...
}

module "storage" {
  source = "./modules/storage"

  environment         = var.environment
  minio_api_port      = var.minio_api_port
  minio_console_port  = var.minio_console_port
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
  postgres_password   = var.postgres_password
  artifact_bucket     = var.artifact_bucket
}

module "mlflow" {
  source = "./modules/mlflow"

  environment         = var.environment
  network_name        = module.storage.network_name
  mlflow_port         = var.mlflow_port
  ...
  depends_on = [module.storage]
}
```

Un **módulo** es una carpeta con sus propios `.tf` que se invoca como si fuera un recurso más.
Sirve para agrupar piezas que siempre van juntas (aquí: "todo lo de storage" y "todo lo de
mlflow") detrás de una interfaz simple: variables de entrada, outputs de salida.

Tres cosas para notar:

- **`terraform_data.environment_guard`** — valida que no mezcles un archivo de variables con
  el workspace equivocado. `dev.tfvars` puede correr en `default`; `prod.tfvars` debe correr
  en `prod`. Si alguien ejecuta `terraform apply -var-file=prod.tfvars` desde `default`,
  Terraform corta antes de reutilizar el state de dev.

- **`module.storage.network_name`** — así se lee el *output* de un módulo desde otro. El
  módulo `mlflow` necesita saber a qué red Docker conectarse, pero esa red la crea `storage`.
  Este es el mecanismo de conexión entre módulos: outputs de uno → variables de otro.
- **`depends_on = [module.storage]`** — Terraform normalmente infiere el orden por las
  referencias (`module.storage.network_name` ya implica una dependencia). Este `depends_on`
  explícito refuerza que *todo* storage (incluyendo el contenedor que crea el bucket) exista
  antes de levantar MLflow, no solo la red.

El módulo `serving` es opcional:

```hcl
module "serving" {
  count  = var.enable_serving ? 1 : 0
  source = "./modules/serving"
  ...
}
```

`count = 0 o 1` es el patrón estándar para "recurso condicional" en Terraform (no existe un
`if` de verdad). Con `enable_serving = false` (el default), este módulo directamente no
existe — por eso el `main.tf` raíz sigue siendo, en la práctica, "dos módulos" como pide el
TODO 4, y el tercero aparece solo cuando se lo pide explícitamente.

### Los bloques `moved` — refactor sin destruir nada

```hcl
moved {
  from = docker_container.mlflow
  to   = module.mlflow.docker_container.mlflow
}
```

Cuando un recurso se "muda" de lugar en el código (aquí: de la raíz a un módulo), Terraform lo
ve como una entidad distinta *a menos que le digas lo contrario* — porque el nombre completo
(`docker_container.mlflow` vs `module.mlflow.docker_container.mlflow`) es parte de su
identidad en el **state**. Sin `moved`, un `plan` después de este refactor mostraría "destruir
+ crear" para cada recurso. El bloque `moved` le dice a Terraform "es el mismo recurso, solo
actualiza la dirección en el state" — el `plan` da limpio, sin tocar la infraestructura real.
Este es el mecanismo detrás de la promesa del TODO 4: *"el plan no debe cambiar nada de
infra — solo reorganizaste el código"*.

---

## 6. Dentro de un módulo: `modules/storage/main.tf`

```hcl
resource "docker_network" "mlops" {
  name = "mlops-${var.environment}"
}

resource "docker_volume" "postgres_data" {
  name = "mlops-pg-${var.environment}"
}
```

Un `resource` es la unidad mínima: "quiero que exista esto". El *tipo* (`docker_network`,
`docker_volume`) lo define el provider; el *nombre local* (`mlops`, `postgres_data`) es solo
una etiqueta para referenciarlo dentro del código — no es el nombre real del recurso en
Docker (ese lo fija el argumento `name = ...`).

```hcl
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

- **`docker_image.postgres.image_id`** — referenciar un atributo de *otro* recurso (`image_id`
  de la imagen que se declaró arriba) es cómo Terraform arma el grafo de dependencias
  automáticamente: como este contenedor usa ese atributo, Terraform sabe que primero tiene que
  bajar/construir la imagen, después crear el contenedor.
- **`aliases = ["postgres"]`** — dentro de la red Docker, cualquier otro contenedor puede
  resolver este servicio por el nombre `postgres` (DNS interno de Docker), sin importar cómo
  se llame el contenedor real. Por eso el `backend-store-uri` de MLflow apunta a
  `postgres:5432` y no a `postgres-dev:5432`.
- **`healthcheck`** — no es una construcción de Terraform, es un argumento que el provider de
  Docker expone porque Docker mismo soporta healthchecks. Terraform simplemente lo declara; el
  chequeo real lo corre el daemon de Docker.
- **El bucket "job"**:

```hcl
resource "docker_container" "create_bucket" {
  name     = "create-bucket-${var.environment}"
  must_run = false # es un job, no un servicio permanente
  restart  = "no"
  ...
  depends_on = [docker_container.minio]
}
```

  `must_run = false` + `restart = "no"` modelan un contenedor que corre una vez y termina
  (crea el bucket con `mc mb`) — no un servicio de larga duración. Es la forma declarativa de
  un "init job", un patrón común en infra de contenedores.

---

## 7. Outputs de módulo: la interfaz hacia afuera

```hcl
# modules/storage/outputs.tf
output "network_name" {
  description = "Nombre de la red docker compartida por el stack"
  value       = docker_network.mlops.name
}
```

Un módulo solo expone lo que declara en sus `outputs.tf`. Todo lo demás (los recursos
`docker_volume`, `docker_container.create_bucket`, etc.) es un detalle interno que el resto
del código ni ve. Esto es encapsulación: `main.tf` raíz solo necesita saber que existe
`module.storage.network_name`, no cómo se construyó esa red.

Mismo patrón en la raíz, hacia el usuario humano:

```hcl
# terraform/outputs.tf
output "tracking_uri" {
  description = "MLFLOW_TRACKING_URI para el script de training"
  value       = "http://localhost:${var.mlflow_port}"
}
```

Esto es lo que ves al correr `terraform output` (o `make output`): la "fachada" pensada para
quien usa el stack, no para quien lo programa.

---

## 8. El módulo `serving` — composición condicional (TODO 5)

```hcl
# modules/serving/main.tf
resource "docker_container" "serving" {
  ...
  command = [
    "mlflow", "models", "serve",
    "-m", "models:/${var.model_name}/${var.model_version}",
    "--host", "0.0.0.0",
    "--port", "5000",
    "--env-manager", "local"
  ]
  ports {
    internal = 5000
    external = var.serving_port
  }
}
```

Este módulo no inventa nada nuevo respecto a `storage`/`mlflow`: mismo patrón (imagen +
contenedor + red + puerto). Lo interesante pedagógicamente es *cómo se conecta* con el resto
del stack sin acoplarse a su implementación:

- Recibe `network_name` (de `module.storage`) para entrar a la misma red Docker.
- Recibe `tracking_uri = "http://mlflow:5000"` (nombre DNS interno, no `localhost`) para poder
  resolver `models:/iris-clf/1` contra el Model Registry que corre en `module.mlflow`.
- Recibe las credenciales de MinIO para poder *descargar* el artefacto del modelo desde el
  bucket S3-compatible.

Y en la raíz, es *opcional* vía `count`:

```hcl
module "serving" {
  count = var.enable_serving ? 1 : 0
  ...
}
```

Por eso, para leer su output hay que indexar el módulo como si fuera una lista:

```hcl
output "serving_url" {
  value = var.enable_serving ? module.serving[0].serving_url : null
}
```

`module.serving` con `count` es una **lista de instancias** (de 0 o 1 elemento aquí), no una
instancia única — de ahí el `[0]`.

---

## 9. El grafo completo, de un vistazo

```
                    var.environment / *.tfvars
                              │
                ┌─────────────┴─────────────┐
                │                           │
         module.storage              (variables compartidas)
        (red, volúmenes,                    │
         postgres, minio,                   │
         bucket init)                       │
                │ network_name               │
                ▼                           │
         module.mlflow  ◄────────────────────┘
        (tracking server,
         usa postgres +
         minio por DNS)
                │ tracking_uri (interno)
                ▼
      module.serving [count = 0|1]
     (sirve un modelo del
      Model Registry vía
      mlflow models serve)
```

Cada flecha es una dependencia real en el grafo de Terraform: no está escrita a mano en
ningún lado ("primero storage, después mlflow"), surge de que un módulo *usa* el output de
otro. Es la misma lógica de `docker_image.X.image_id` dentro de un módulo, pero a nivel de
módulos completos.
