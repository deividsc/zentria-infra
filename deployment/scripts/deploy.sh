#!/bin/bash
# ===========================================
# Deploy Script para Odoo en GCP
# ===========================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
PROJECT_NAME="zentria-odoo"
REMOTE_USER="odoo"
REMOTE_HOST=""
DEPLOY_PATH="/opt/odoo"

echo -e "${GREEN}=== Zentria Odoo Deploy Script ===${NC}\n"

# Funciones
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prereqs() {
    log_info "Verificando prerequisitos..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI no está instalado"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose no está instalado"
        exit 1
    fi
    
    log_info "Todos los prerequisitos están instalados"
}

deploy() {
    log_info "Iniciando despliegue..."
    
    # Validar variables
    if [ -z "$REMOTE_HOST" ]; then
        read -p "Ingresá la IP del servidor: " REMOTE_HOST
    fi
    
    # Copiar archivos
    log_info "Copiando archivos al servidor..."
    rsync -avz --delete \
        -e "ssh -i ~/.ssh/google_compute_engine" \
        --exclude='.env' \
        --exclude='*.log' \
        --exclude='backups/' \
        ./ docker-compose.yml ${REMOTE_USER}@${REMOTE_HOST}:${DEPLOY_PATH}/
    
    # Copiar .env separately
    if [ -f .env ]; then
        log_info "Copiando configuración..."
        scp -i ~/.ssh/google_compute_engine .env ${REMOTE_USER}@${REMOTE_HOST}:${DEPLOY_PATH}/.env
    fi
    
    # Ejecutar en servidor remoto
    log_info "Ejecutando despliegue en servidor..."
    ssh -i ~/.ssh/google_compute_engine ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
        cd /opt/odoo
        
        # Crear directorios si no existen
        mkdir -p config addons custom_addons backups nginx/ssl nginx/logs nginx/www
        
        # Detener servicios existentes
        docker compose down 2>/dev/null || true
        
        # Pull imágenes
        docker compose pull
        
        # Iniciar servicios
        docker compose up -d
        
        # Esperar a Odoo
        echo "Esperando que Odoo esté listo..."
        sleep 10
        
        # Verificar estado
        docker compose ps
ENDSSH
    
    log_info "Despliegue completado!"
    log_info "Accedé a: http://${REMOTE_HOST}:8069"
}

backup() {
    log_info "Creando backup..."
    
    if [ -z "$REMOTE_HOST" ]; then
        read -p "Ingresá la IP del servidor: " REMOTE_HOST
    fi
    
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    
    ssh -i ~/.ssh/google_compute_engine ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
        cd /opt/odoo
        mkdir -p backups
        
        # Backup de PostgreSQL
        docker compose exec -T db pg_dump -U odoo odoo > backups/odoo_backup_${BACKUP_DATE}.sql
        
        # Backup de filestore
        tar -czf backups/filestore_${BACKUP_DATE}.tar.gz -C /var/lib/odoo data/filestore 2>/dev/null || true
        
        echo "Backups creados:"
        ls -lh backups/
ENDSSH
    
    log_info "Backup completado: ${BACKUP_DATE}"
}

restore() {
    log_info "Restaurando backup..."
    
    if [ -z "$REMOTE_HOST" ]; then
        read -p "Ingresá la IP del servidor: " REMOTE_HOST
    fi
    
    read -p "Nombre del backup (sin extensión): " BACKUP_FILE
    
    ssh -i ~/.ssh/google_compute_engine ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
        cd /opt/odoo
        
        # Restaurar PostgreSQL
        cat backups/${BACKUP_FILE}.sql | docker compose exec -T db psql -U odoo -d odoo
        
        echo "Restauración completada"
ENDSSH
}

status() {
    log_info "Verificando estado de servicios..."
    
    if [ -z "$REMOTE_HOST" ]; then
        read -p "Ingresá la IP del servidor: " REMOTE_HOST
    fi
    
    ssh -i ~/.ssh/google_compute_engine ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
        cd /opt/odoo
        docker compose ps
        echo ""
        echo "Logs recientes:"
        docker compose logs --tail=20
ENDSSH
}

# Menú
case "${1:-}" in
    deploy)
        check_prereqs
        deploy
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    status)
        status
        ;;
    *)
        echo "Uso: $0 {deploy|backup|restore|status}"
        echo ""
        echo "Comandos:"
        echo "  deploy   - Desplegar Odoo en el servidor"
        echo "  backup   - Crear backup de la base de datos"
        echo "  restore  - Restaurar desde un backup"
        echo "  status   - Ver estado de los servicios"
        exit 1
        ;;
esac
