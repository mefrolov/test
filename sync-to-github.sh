#!/bin/bash

# Простой скрипт для синхронизации с GitHub
# Этот скрипт копирует файлы из папки public в GitHub репозиторий

echo "🔄 Начинаем синхронизацию с GitHub..."

# Проверяем, что папка public существует
if [ ! -d "public" ]; then
    echo "❌ Ошибка: папка 'public' не найдена!"
    echo "Создайте папку 'public' и поместите туда файлы для портфолио"
    exit 1
fi

# Проверяем, что есть файлы для синхронизации
if [ -z "$(ls -A public)" ]; then
    echo "⚠️  Папка 'public' пуста. Добавьте файлы для синхронизации"
    exit 1
fi

# Получаем сообщение последнего коммита
LAST_COMMIT_MSG=$(git log -1 --pretty=format:"%s")
echo "📝 Последний коммит: $LAST_COMMIT_MSG"

# Создаем временную папку
TEMP_DIR="temp_github_sync"
mkdir -p "$TEMP_DIR"

# Копируем содержимое public во временную папку
echo "📁 Копируем файлы из public/..."
cp -r public/* "$TEMP_DIR/"

# Клонируем GitHub репозиторий во временную папку
echo "📥 Подключаемся к GitHub репозиторию..."
git clone $(git remote get-url github) "$TEMP_DIR/github_repo"

# Переходим в GitHub репозиторий
cd "$TEMP_DIR/github_repo"

# Удаляем все файлы кроме .git (чтобы заменить на новые)
find . -maxdepth 1 ! -name '.' ! -name '.git' -exec rm -rf {} + 2>/dev/null

# Копируем новые файлы из public
echo "📋 Обновляем файлы в GitHub репозитории..."
cp -r ../* . 2>/dev/null
rm -rf github_repo 2>/dev/null  # Удаляем вложенную копию репозитория

# Проверяем, есть ли изменения
if git diff --quiet && git diff --staged --quiet; then
    echo "✅ Нет изменений для синхронизации"
    cd ../..
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Добавляем все изменения
git add .

# Создаем коммит с сообщением
echo "💾 Создаем коммит..."
git commit -m "📊 $LAST_COMMIT_MSG

Синхронизировано из приватного репозитория
Дата: $(date '+%Y-%m-%d %H:%M:%S')"

# Отправляем в GitHub
echo "🚀 Отправляем изменения в GitHub..."
git push origin main

# Возвращаемся в исходную папку и убираем временные файлы
cd ../..
rm -rf "$TEMP_DIR"

echo "✅ Синхронизация завершена успешно!"
echo "🔗 Проверьте ваш GitHub: $(git remote get-url github)"