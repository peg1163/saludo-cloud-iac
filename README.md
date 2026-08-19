# Saludo Cloud IaC

Infraestructura de Saludo Cloud creada con Terraform sobre Azure Container Apps.

## Recursos

- Resource Group.
- Log Analytics Workspace con límite diario de 0.1 GB.
- Container Apps Environment.
- Container App con acceso público.

La aplicación utiliza la imagen `peg1163/saludo-cloud:v1` y escucha en el puerto 8080.

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

No se deben subir a Git los archivos `terraform.tfstate`, `.tfvars` ni los planes generados.
