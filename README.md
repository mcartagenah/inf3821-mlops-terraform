# Práctico MLOps — Infra-as-Code con Terraform + Docker

En este práctico vas a levantar un stack completo de **MLflow** (tracking server + backend Postgres + artifact store MinIO) **usando Terraform**, sin tocar la consola de Docker a mano. Vas a escribir y correr IaC de verdad: `plan`, `apply`, `destroy`.

El modelo de ML es intencionalmente trivial (un `LogisticRegression` sobre iris). **El foco es la infraestructura, no el modelo.**

---

## Arquitectura

```
        ┌─────────────┐        ┌──────────────┐
        │   MLflow    │───────▶│  PostgreSQL  │   metadata (params, métricas, runs)
        │  :5000 UI   │        └──────────────┘
        │             │        ┌──────────────┐
        │             │───────▶│    MinIO     │   artefactos (modelos serializados)
        └─────────────┘        │ :9000 / :9001│
                               └──────────────┘
        Todo declarado en Terraform. Todo corre en contenedores Docker.
```

---

## Cómo correrlo

Hay dos caminos. Usa **A** salvo que no puedas.

### Plan A — GitHub Codespaces (recomendado)

1. En este repo: botón verde **Code → Codespaces → Create codespace on main**.
2. Espera a que el devcontainer termine de construirse (trae Docker y Terraform listos).
3. En la pestaña **PORTS** verás los puertos 5000, 9000 y 9001 una vez que levantes el stack.

> ⚠️ En Codespaces la UI de MLflow **NO** está en `localhost:5000`, sino en la URL que GitHub genera para el puerto 5000 (pestaña PORTS → ícono del globo). El `train.py` sí usa `localhost:5000` porque corre *dentro* del Codespace.

### Plan B — Docker Desktop local

Requisitos: **Docker Desktop** corriendo + **Terraform ≥ 1.6** instalado.

```bash
git clone <URL-de-este-repo>
cd mlops-iac-practico
pip install -r ml/requirements.txt
```

---

## Levantar el stack

Hay dos formas equivalentes. Los **atajos con `make`** son más cómodos; los
**comandos crudos** te muestran qué hay detrás (apréndelos, son la gracia del práctico).

Con `make` (desde la raíz del repo):

```bash
make init    # descarga el provider docker
make up      # levanta el stack dev
make output  # muestra las URLs
```

Comando crudo equivalente:

```bash
cd terraform
terraform init
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
terraform output
```

`make output` (o `terraform output`) te da las URLs. Abre la UI de MLflow y la consola de
MinIO (usuario/password por defecto: `minioadmin` / `minioadmin`).

> Corre `make help` para ver todos los atajos disponibles.

## Loguear experimentos

```bash
make train        # atajo
# o bien:
python ml/train.py
```

Deberías ver 3 runs aparecer en el experimento `practico-iac` en MLflow, y una carpeta
por run dentro del bucket `mlflow-artifacts` en la consola de MinIO.

---

## TODOs

Resuélvelos en orden. Cada uno dice qué deberías observar si lo lograste.

### TODO 1 — Loop de reproducibilidad *(imprescindible)*

```bash
cd terraform
terraform destroy -var-file=dev.tfvars   # todo desaparece
terraform apply   -var-file=dev.tfvars   # vuelve idéntico
```

**Observa:** el stack se reconstruye completo desde el código. Esto es el corazón de IaC.
*Pregunta:* después del destroy + apply, ¿siguen ahí tus runs anteriores? ¿Por qué sí o por qué no?
(Pista: mira qué volúmenes borra el `destroy` y cuáles no.)

### TODO 2 — Drift: estado real vs. estado deseado

Rompe el stack a mano y deja que Terraform lo detecte:

```bash
docker stop mlflow-dev
terraform plan -var-file=dev.tfvars
```

**Observa:** Terraform nota que el contenedor no está corriendo y propone recrearlo.
Corre `terraform apply` y vuelve al estado deseado. Esto es *desired-state* vs. imperativo.

### TODO 3 — Ambientes con tfvars

Levanta un segundo stack `prod` aislado, en paralelo al `dev`:

```bash
terraform apply -var-file=prod.tfvars
```

**Observa:** dos stacks completos coexistiendo (puertos 5001/9010/9011), generados por
**el mismo código**. Cambió solo el `-var-file`. Recuerda hacer `destroy` de ambos al final.

Con ambos stacks corriendo, entrena contra uno u otro pasando `--tracking-uri`:

```bash
python ml/train.py --tracking-uri http://localhost:5000   # dev
python ml/train.py --tracking-uri http://localhost:5001   # prod
```

(También puedes definir la variable de entorno `MLFLOW_TRACKING_URI` en vez del flag.)

### TODO 4 — Refactor a módulos *(avanzado)*

Extrae el storage (Postgres + MinIO + bucket) a un módulo `modules/storage` y MLflow a
`modules/mlflow`. El `main.tf` raíz debería quedar como dos llamadas `module { ... }`.
**Observa:** el `plan` no debe cambiar nada de infra — solo reorganizaste el código.

### TODO 5 — Agrega un servicio *(abierto)*

Extiende el stack con una pieza más para practicar composición. Opciones:
- un contenedor de **model serving** (`mlflow models serve`), o
- **Prometheus + Grafana** para monitoreo básico.

---

## Al terminar: LIMPIA

```bash
make clean   # destruye dev y prod de una vez
# o bien, uno por uno:
cd terraform
terraform destroy -var-file=dev.tfvars
terraform destroy -var-file=prod.tfvars   # si levantaste prod
```

**Plan A (Codespaces):** además, borra el Codespace desde
github.com/codespaces → tu Codespace → **Delete**. Un Codespace detenido igual consume
tu cuota de almacenamiento. (Borrar recursos que ya no usas es, justamente, la lección.)
