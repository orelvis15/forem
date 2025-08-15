# 🚀 Guía de Releases - Forem con Wasabi

Esta guía describe el proceso completo para crear releases de tu versión personalizada de Forem con soporte para Wasabi S3.

## 📋 Estructura de Ramas

```
main                    ← Sincronizada con upstream (forem oficial)
├── maindev            ← Tu rama personalizada con modificaciones
│   └── release/x.x.x  ← Ramas de release desde maindev
└── feature/*          ← Ramas de desarrollo temporal
```

## 🔄 Actualización desde Upstream

### 1. Actualizar main desde el repositorio oficial

```bash
# Cambiar a la rama main
git checkout main

# Obtener cambios del repositorio oficial de Forem
git fetch upstream

# Aplicar cambios manteniendo historial limpio
git rebase upstream/main

# Subir cambios a tu fork
git push origin main
```

### 2. Actualizar maindev con los cambios de main

```bash
# Cambiar a la rama maindev
git checkout maindev

# Aplicar cambios de main a maindev (incluye tus modificaciones)
git rebase main

# Si hay conflictos, resolverlos y continuar:
# 1. Editar archivos con conflictos
# 2. git add .
# 3. git rebase --continue

# Subir cambios actualizados
git push origin maindev --force-with-lease
```

### Script de Automatización para Actualizaciones

Crea un archivo `update-fork.sh`:

```bash
#!/bin/bash
# update-fork.sh

echo "🔄 Actualizando main desde upstream..."
git checkout main
git fetch upstream
git rebase upstream/main

if [ $? -ne 0 ]; then
    echo "❌ Error actualizando main. Resuelve conflictos manualmente."
    exit 1
fi

git push origin main

echo "🔧 Aplicando cambios a maindev..."
git checkout maindev
git rebase main

if [ $? -ne 0 ]; then
    echo "⚠️  Conflictos detectados en maindev."
    echo "Resuelve conflictos y ejecuta:"
    echo "  git add ."
    echo "  git rebase --continue"
    echo "  git push origin maindev --force-with-lease"
    exit 1
fi

git push origin maindev --force-with-lease
echo "✅ Fork actualizado exitosamente"
```

Hacer ejecutable:
```bash
chmod +x update-fork.sh
```

## 🛠️ Desarrollo de Cambios

### 1. Hacer modificaciones en maindev

```bash
# Asegurar que maindev está actualizado
git checkout maindev
git pull origin maindev

# Hacer tus modificaciones (ej: config/initializers/carrierwave.rb)
# Editar archivos...

# Commit de cambios
git add .
git commit -m "feat: descripción de los cambios"
git push origin maindev
```

## 🚀 Crear Nueva Release

### Script de Release

Crea un archivo `create-release.sh`:

```bash
#!/bin/bash
# create-release.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.3"
    exit 1
fi

VERSION=$1
RELEASE_BRANCH="release/$VERSION"

echo "🚀 Creando release v$VERSION desde maindev..."

# Verificar que estamos en maindev y está actualizado
git checkout maindev
git pull origin maindev

# Verificar si la rama release ya existe
if git show-ref --verify --quiet refs/heads/$RELEASE_BRANCH; then
    echo "⚠️  La rama $RELEASE_BRANCH ya existe. Actualizándola..."
    
    # Cambiar a la rama existente
    git checkout $RELEASE_BRANCH
    
    # Hacer rebase desde maindev
    git rebase maindev
    
    if [ $? -ne 0 ]; then
        echo "❌ Conflictos durante rebase. Resuelve manualmente:"
        echo "  1. Resolver conflictos"
        echo "  2. git add ."
        echo "  3. git rebase --continue"
        echo "  4. git push origin $RELEASE_BRANCH --force-with-lease"
        exit 1
    fi
    
    # Push forzado de la rama actualizada
    git push origin $RELEASE_BRANCH --force-with-lease
    echo "✅ Rama $RELEASE_BRANCH actualizada"
    
else
    echo "📝 Creando nueva rama $RELEASE_BRANCH..."
    
    # Crear nueva rama de release desde maindev
    git checkout -b $RELEASE_BRANCH
    
    # Actualizar versión si tienes archivo de versión
    # echo "$VERSION" > VERSION
    # git add VERSION
    
    # Commit de release
    git commit --allow-empty -m "chore: release v$VERSION

- Update version to $VERSION
- Based on maindev with Wasabi S3 support
- Ready for production deployment"
    
    # Push de nueva rama
    git push origin $RELEASE_BRANCH
    echo "✅ Nueva rama $RELEASE_BRANCH creada"
fi

echo ""
echo "🔄 GitHub Actions construirá automáticamente:"
echo "   📦 ghcr.io/$(git config remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/forem:$VERSION"
echo "   📦 ghcr.io/$(git config remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/forem:latest"
echo ""
echo "🔗 Monitorea el progreso en:"
echo "   https://github.com/$(git config remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
```

Hacer ejecutable:
```bash
chmod +x create-release.sh
```

### Uso del Script de Release

```bash
# Crear nueva release
./create-release.sh 1.0.0

# Actualizar release existente
./create-release.sh 1.0.0
```

## 📦 Proceso Automático

Una vez que ejecutes el script de release:

1. **GitHub Actions detecta** el push a `release/x.x.x`
2. **Construye la imagen Docker** desde cero con tus modificaciones
3. **Sube la imagen** a `ghcr.io/tu-usuario/forem:x.x.x`
4. **Crea un GitHub Release** con changelog y instrucciones
5. **Taguea también como** `latest` si es la versión más reciente

## 🔍 Verificación de Release

### Monitorear el Build

```bash
# Ver el estado en GitHub
echo "🔗 https://github.com/$(git config remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"

# Verificar que la imagen se subió correctamente
docker pull ghcr.io/tu-usuario/forem:1.0.0
```

### Verificar Funcionalidad

```bash
# Test local de la nueva imagen
docker run --rm \
  -e AWS_S3_ENDPOINT=https://s3.wasabisys.com \
  -e AWS_ID=test_key \
  -e AWS_SECRET=test_secret \
  -p 3000:3000 \
  ghcr.io/tu-usuario/forem:1.0.0
```

## 🚨 Troubleshooting

### Si el rebase falla en maindev

```bash
# Resolver conflictos manualmente
git status  # Ver archivos en conflicto
# Editar archivos y resolver conflictos
git add .
git rebase --continue
git push origin maindev --force-with-lease
```

### Si el build de GitHub Actions falla

1. **Revisar logs** en la pestaña Actions del repositorio
2. **Verificar permisos** en Settings → Actions → General
3. **Comprobar Dockerfile** y configuración de carrierwave.rb

### Si la imagen no funciona

```bash
# Ejecutar en modo debug
docker run --rm -it \
  -e AWS_S3_ENDPOINT=https://s3.wasabisys.com \
  ghcr.io/tu-usuario/forem:1.0.0 \
  /bin/bash

# Ver logs de la aplicación
docker logs container_name
```

## 📊 Workflow Completo de Ejemplo

```bash
# 1. Actualizar desde upstream
./update-fork.sh

# 2. Desarrollar cambios
git checkout maindev
# ... hacer modificaciones ...
git add .
git commit -m "feat: nueva funcionalidad"
git push origin maindev

# 3. Crear release
./create-release.sh 1.2.0

# 4. Monitorear build
# Ir a GitHub Actions y verificar que el build sea exitoso

# 5. Usar la nueva imagen
docker pull ghcr.io/tu-usuario/forem:1.2.0
```

## 🎯 Mejores Prácticas

- ✅ **Siempre actualizar** desde upstream antes de crear releases
- ✅ **Usar versionado semántico** (MAJOR.MINOR.PATCH)
- ✅ **Probar localmente** antes de hacer push
- ✅ **Revisar GitHub Actions** para cada release
- ✅ **Documentar cambios** en los commits
- ✅ **Mantener maindev limpio** y actualizado

## 📝 Versionado Semántico

- **MAJOR** (1.0.0 → 2.0.0): Cambios que rompen compatibilidad
- **MINOR** (1.0.0 → 1.1.0): Nuevas funcionalidades compatibles
- **PATCH** (1.0.0 → 1.0.1): Correcciones de bugs

## 🔗 Links Útiles

- **GitHub Actions**: `https://github.com/tu-usuario/forem/actions`
- **Packages**: `https://github.com/tu-usuario/forem/pkgs/container/forem`
- **Releases**: `https://github.com/tu-usuario/forem/releases`
- **Docker Hub**: `https://ghcr.io/tu-usuario/forem`