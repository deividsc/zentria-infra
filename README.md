# Zentria Infrastructure

Infraestructura y configuración de deployment para Zentria CRM.

## Contenido

```
├── deployment/
│   ├── docker/           # Docker Compose, configs
│   ├── gcp/              # Scripts de GCP
│   └── scripts/          # Scripts de automatización
```

## Setup Local

```bash
# Copiar variables de entorno
cp deployment/docker/.env.example deployment/docker/.env

# Levantar servicios
cd deployment/docker
docker compose up -d
```

## Deploy a GCP

```bash
cd deployment/scripts
./deploy.sh deploy
```

## Documentación

Ver `deployment/` para guías de deployment.

## Commits

Usar commits convencionales:
- `feat:` Nuevas funcionalidades
- `fix:` Bug fixes
- `docs:` Documentación
- `refactor:` Refactoring
- `chore:` Tareas varias
