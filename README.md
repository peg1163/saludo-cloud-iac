# Saludo Cloud IaC

Infraestructura de Saludo Cloud creada con Terraform sobre Azure Container Apps.

## Recursos

- Resource Group.
- Log Analytics Workspace con límite diario de 0.1 GB.
- Container Apps Environment.
- Container App con acceso público.

La aplicación recibe una referencia inmutable de imagen mediante
`container_image` y escucha en el puerto definido por `container_port`. El
pipeline de `saludo-cloud-api` construye y publica la imagen; Terraform no
construye el código Java.

Flujo de entrega:

```text
saludo-cloud-api
    -> GitHub Actions: tests y build
    -> GHCR: imagen inmutable por digest
    -> workflow reutilizable de saludo-cloud-iac
    -> validación del contrato container_image
    -> Terraform
    -> Azure Container Apps
```

El workflow reutilizable `.github/workflows/image-contract.yml` recibe desde el
repositorio de la API una referencia con el formato:

```text
ghcr.io/peg1163/saludo-cloud@sha256:<digest>
```

La ejecución deja el traspaso API → IaC registrado en el resumen de GitHub
Actions. Este paso valida el contrato y no ejecuta `terraform apply`; el
despliegue requiere una aprobación independiente.

## Uso

Primero inicia sesión y carga la suscripción activa:

```bash
az login
export TF_VAR_subscription_id="$(az account show --query id --output tsv)"
```

Después valida el proyecto:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

La referencia de imagen debe entregarse expresamente:

```bash
terraform plan \
  -var="container_image=ghcr.io/peg1163/saludo-cloud@sha256:<digest>" \
  -out=tfplan
```

Para desplegar el plan revisado:

```bash
terraform apply tfplan
```

Las URLs se obtienen con:

```bash
terraform output
```

Para eliminar los recursos al terminar:

```bash
terraform destroy
```

No se deben subir a Git los archivos `terraform.tfstate`, `.tfvars` ni los planes
generados. El archivo `.terraform.lock.hcl` sí debe versionarse para fijar la
versión seleccionada del provider.

## Pendientes para el despliegue real

- Crear Azure Container Registry e identidad administrada con rol `AcrPull`, o
  configurar autenticación si la imagen de GHCR permanece privada.
- Configurar un backend remoto `azurerm` para el estado.
- Configurar autenticación OIDC de GitHub Actions hacia Azure.
