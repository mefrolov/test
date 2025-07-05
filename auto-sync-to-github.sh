#!/bin/bash

# Скрипт синхронизации с файлом настроек
# Читает настройки из .syncconfig

echo "🔄 Селективная синхронизация с GitHub..."

# Создаем конфигурационный файл если его нет
if [ ! -f ".syncconfig" ]; then
    echo "📝 Создаем файл настроек .syncconfig..."
    cat > .syncconfig << 'EOF'
# Конфигурация синхронизации с GitHub
# Один паттерн на строку

# Включаем файлы (поддерживает glob паттерны)
INCLUDE:
*.ipynb
*.py
*.sql
analysis/*.csv
docs/*.md
README.md
requirements.txt

# Исключаемые паттерны (более приоритетные)
EXCLUDE:
*private*
*secret*
*password*
*key*
*config*
temp/*
cache/*
.env
*.log
__pycache__/*
.git/*

# Исключаемые папки целиком
EXCLUDE_DIRS:
private
secrets
temp
cache
.git
__pycache__
node_modules
EOF
    echo "✅ Создан файл .syncconfig - отредактируйте его под свои нужды"
    echo "Затем запустите скрипт снова"
    exit 0
fi

# Читаем конфигурацию
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()
EXCLUDE_DIRS=()

current_section=""
while IFS= read -r line; do
    # Пропускаем комментарии и пустые строки
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Определяем секцию
    if [[ "$line" == "INCLUDE:" ]]; then
        current_section="include"
        continue
    elif [[ "$line" == "EXCLUDE:" ]]; then
        current_section="exclude"
        continue
    elif [[ "$line" == "EXCLUDE_DIRS:" ]]; then
        current_section="exclude_dirs"
        continue
    fi
    
    # Добавляем паттерн в соответствующий массив
    case "$current_section" in
        "include")
            INCLUDE_PATTERNS+=("$line")
            ;;
        "exclude")
            EXCLUDE_PATTERNS+=("$line")
            ;;
        "exclude_dirs")
            EXCLUDE_DIRS+=("$line")
            ;;
    esac
done < .syncconfig

echo "🔍 Ищем файлы по настройкам..."
echo "  📋 Включаемых паттернов: ${#INCLUDE_PATTERNS[@]}"
echo "  🚫 Исключаемых паттернов: ${#EXCLUDE_PATTERNS[@]}"
echo "  📁 Исключаемых папок: ${#EXCLUDE_DIRS[@]}"

# Функция проверки исключения
should_exclude() {
    local file="$1"
    local filename=$(basename "$file")
    local filepath="$file"
    
    # Проверяем исключаемые папки
    for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$filepath" == *"$exclude_dir"* ]]; then
            return 0  # исключить
        fi
    done
    
    # Проверяем исключаемые паттерны
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$filepath" == $pattern ]] || [[ "$filename" == $pattern ]]; then
            return 0  # исключить
        fi
    done
    
    return 1  # не исключать
}

# Создаем временную папку
TEMP_DIR="temp_github_sync"
mkdir -p "$TEMP_DIR"

# Ищем и копируем файлы
file_count=0
for pattern in "${INCLUDE_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
        # Убираем ./ в начале пути
        clean_file="${file#./}"
        
        if should_exclude "$clean_file"; then
            continue
        fi
        
        # Создаем папки и копируем файл
        target_dir="$TEMP_DIR/$(dirname "$clean_file")"
        mkdir -p "$target_dir"
        cp "$file" "$target_dir/"
        
        echo "  ✓ $clean_file"
        ((file_count++))
    done < <(find . -path "./.git" -prune -o -name "$pattern" -type f -print0 2>/dev/null)
done

if [ $file_count -eq 0 ]; then
    echo "⚠️  Не найдено файлов для синхронизации"
    echo "Проверьте настройки в .syncconfig"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "📁 Найдено файлов: $file_count"

# Получаем сообщение коммита
LAST_COMMIT_MSG=$(git log -1 --pretty=format:"%s")

# Клонируем GitHub репозиторий
echo "📥 Подключаемся к GitHub..."
git clone $(git remote get-url github) "$TEMP_DIR/github_repo"

cd "$TEMP_DIR/github_repo"

# Очищаем репозиторий
find . -maxdepth 1 ! -name '.' ! -name '.git' -exec rm -rf {} + 2>/dev/null

# Копируем новые файлы
echo "📋 Обновляем GitHub репозиторий..."
find .. -maxdepth 10 ! -name 'github_repo' ! -name '.' -exec cp -r {} . \; 2>/dev/null
find . -name 'github_repo' -type d -exec rm -rf {} + 2>/dev/null

# Проверяем изменения
if git diff --quiet && git diff --staged --quiet; then
    echo "✅ Нет изменений"
    cd ../..
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Коммитим и пушим
git add .
git commit -m "🔄 Selective sync: $LAST_COMMIT_MSG

📊 Файлов синхронизировано: $file_count
⚙️  Конфигурация: .syncconfig
📅 $(date '+%Y-%m-%d %H:%M:%S')"

git push origin main

cd ../..
rm -rf "$TEMP_DIR"

echo "✅ Селективная синхронизация завершена!"
echo "📊 Синхронизировано: $file_count файлов"