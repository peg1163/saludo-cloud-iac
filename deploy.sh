#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso: ./deploy.sh [--plan-only] [--auto-approve]

Construye y publica Saludo Cloud, prepara un plan de Terraform y, después de
una confirmación explícita, despliega la imagen en Azure Container Apps.

Opciones:
  --plan-only     Publica la imagen y genera el plan, pero no lo aplica.
  --auto-approve  Aplica el plan sin solicitar la confirmación APLICAR.
  -h, --help      Muestra esta ayuda.

Variables opcionales:
  API_DIR           Ruta del repositorio saludo-cloud-api.
  IMAGE_REPOSITORY  Repositorio de la imagen (por defecto: GHCR del proyecto).
  IMAGE_TAG         Etiqueta de la imagen (por defecto: sha-<commit>).
  STUDENT_NAME      Nombre que devuelve /hello (por defecto: Jaime Acuña).
  GHCR_USERNAME     Usuario de GitHub, si se inicia sesión desde el script.
  GHCR_TOKEN        Token con permiso write:packages. Nunca se guarda en Git.

Requisitos previos:
  - Sesión activa en Azure CLI: az login
  - Sesión Docker con permiso para publicar en GHCR, o GHCR_USERNAME/GHCR_TOKEN
  - Docker, Docker Buildx, Terraform, Azure CLI, Git y curl instalados
EOF
}

log() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "No se encontró el comando requerido: $1"
}

plan_only=false
auto_approve=false

while (($# > 0)); do
  case "$1" in
    --plan-only)
      plan_only=true
      ;;
    --auto-approve)
      auto_approve=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "Opción desconocida: $1. Usa --help para ver las opciones."
      ;;
  esac
  shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
api_dir="${API_DIR:-$script_dir/../saludo-cloud-api}"
image_repository="${IMAGE_REPOSITORY:-ghcr.io/peg1163/saludo-cloud}"
student_name="${STUDENT_NAME:-Jaime Acuña}"
plan_file=""

cleanup() {
  if [[ -n "$plan_file" && -f "$plan_file" ]]; then
    rm -f -- "$plan_file"
  fi
}
trap cleanup EXIT

for command_name in az curl docker git terraform; do
  require_command "$command_name"
done

[[ -d "$api_dir/.git" ]] || fail "No se encontró el repositorio API en: $api_dir"
[[ -x "$api_dir/gradlew" ]] || fail "No se encontró gradlew ejecutable en: $api_dir"
[[ -f "$api_dir/Dockerfile" ]] || fail "No se encontró el Dockerfile en: $api_dir"

if [[ -n "$(git -C "$api_dir" status --porcelain)" ]]; then
  fail "El repositorio API tiene cambios sin confirmar. Confírmalos antes de crear la imagen."
fi

commit_sha="$(git -C "$api_dir" rev-parse --short=12 HEAD)"
image_tag="${IMAGE_TAG:-sha-$commit_sha}"

if [[ ! "$image_tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  fail "IMAGE_TAG no tiene un formato Docker válido: $image_tag"
fi

log "Comprobando las sesiones y herramientas"
az account show --output none || fail "No hay una sesión activa de Azure CLI. Ejecuta: az login"
docker info >/dev/null || fail "Docker no está disponible. Inicia Docker antes de continuar."
docker buildx version >/dev/null || fail "Docker Buildx no está disponible."

subscription_id="$(az account show --query id --output tsv)"
[[ -n "$subscription_id" ]] || fail "Azure CLI no devolvió una suscripción activa."
export TF_VAR_subscription_id="${TF_VAR_subscription_id:-$subscription_id}"

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  [[ -n "${GHCR_USERNAME:-}" ]] || fail "Define GHCR_USERNAME cuando uses GHCR_TOKEN."
  log "Iniciando sesión en GHCR"
  printf '%s' "$GHCR_TOKEN" |
    docker login ghcr.io --username "$GHCR_USERNAME" --password-stdin >/dev/null
else
  log "Usando la sesión Docker existente para GHCR"
fi

log "Ejecutando las pruebas de la API"
(
  cd "$api_dir"
  ./gradlew clean test --no-daemon
)

versioned_image="$image_repository:$image_tag"
latest_image="$image_repository:latest"

log "Construyendo la imagen $versioned_image"
docker build \
  --platform linux/amd64 \
  --tag "$versioned_image" \
  --tag "$latest_image" \
  "$api_dir"

log "Publicando las etiquetas $image_tag y latest"
docker push "$versioned_image"
docker push "$latest_image"

log "Obteniendo el digest inmutable publicado"
image_digest="$(
  docker buildx imagetools inspect "$versioned_image" \
    --format '{{json .Manifest.Digest}}' | tr -d '"'
)"

if [[ ! "$image_digest" =~ ^sha256:[a-f0-9]{64}$ ]]; then
  fail "No se pudo obtener un digest SHA-256 válido: $image_digest"
fi

container_image="$image_repository@$image_digest"
printf 'Imagen que se desplegará: %s\n' "$container_image"

log "Validando Terraform"
terraform -chdir="$script_dir" init -input=false
terraform -chdir="$script_dir" fmt -check -recursive
terraform -chdir="$script_dir" validate

plan_file="$(mktemp "${TMPDIR:-/tmp}/saludo-cloud.XXXXXX.tfplan")"

log "Generando el plan de Terraform"
terraform -chdir="$script_dir" plan \
  -input=false \
  -var="container_image=$container_image" \
  -var="student_name=$student_name" \
  -out="$plan_file"

terraform -chdir="$script_dir" show -no-color "$plan_file"

if [[ "$plan_only" == true ]]; then
  log "Plan generado correctamente; --plan-only evita el despliegue"
  exit 0
fi

if [[ "$auto_approve" != true ]]; then
  printf '\nEscribe APLICAR para desplegar este plan en Azure: '
  read -r confirmation
  [[ "$confirmation" == "APLICAR" ]] || fail "Despliegue cancelado por el usuario."
fi

log "Aplicando el plan aprobado"
terraform -chdir="$script_dir" apply -input=false "$plan_file"

hello_url="$(terraform -chdir="$script_dir" output -raw hello_url)"
health_url="$(terraform -chdir="$script_dir" output -raw health_url)"

log "Verificando /hello"
curl --fail --show-error --silent --retry 12 --retry-delay 5 "$hello_url"
printf '\n'

log "Verificando /health"
curl --fail --show-error --silent --retry 12 --retry-delay 5 "$health_url"
printf '\n'

log "Despliegue finalizado correctamente"
printf 'Aplicación: %s\n' "$(terraform -chdir="$script_dir" output -raw application_url)"
