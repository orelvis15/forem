#!/bin/bash
# create-release.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.3"
    exit 1
fi

VERSION=$1

echo "🚀 Creando release v$VERSION desde maindev..."

# Verificar que estamos en maindev y está actualizado
git checkout maindev
git pull origin maindev

# Crear rama de release
git checkout -b release/$VERSION

# Actualizar versión si tienes archivo de versión
# echo "$VERSION" > VERSION

# Commit y push
git add .
git commit -m "chore: release v$VERSION

- Update version to $VERSION
- Based on maindev with Wasabi S3 support
- Ready for production deployment"

git push origin release/$VERSION

echo "✅ Rama release/$VERSION creada"
echo "🔄 GitHub Actions construirá automáticamente la imagen:"
echo "   ghcr.io/$(git config remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/forem:$VERSION"