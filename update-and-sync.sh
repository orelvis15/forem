#!/bin/bash
# update-and-sync.sh

echo "🔄 Actualizando main desde upstream..."
git checkout main
git fetch upstream
git rebase upstream/main
git push origin main

echo "🔧 Aplicando cambios a maindev..."
git checkout maindev
git rebase main

# Resolver conflictos si los hay
if [ $? -ne 0 ]; then
    echo "⚠️  Conflictos detectados. Resuelve y ejecuta:"
    echo "git add ."
    echo "git rebase --continue"
    echo "git push origin maindev --force-with-lease"
    exit 1
fi

git push origin maindev --force-with-lease
echo "✅ maindev actualizado con últimos cambios de upstream"