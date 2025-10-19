#!/bin/bash

# source: https://habr.com/ru/articles/953860/

echo "=== Анализ дискового ввода-вывода и поиск файловых дескрипторов ==="
echo "Временная метка: $(date)"
echo ""

# 1. Общая статистика ввода-вывода с помощью iostat
echo "1. Общая статистика I/O (первые 3 секунды - усреднение, потом live):"
echo "------------------------------------------------------------------"
if command -v iostat &> /dev/null; then
    iostat -dx 1 3
else
    echo "Утилита 'iostat' не установлена. Установите пакет 'sysstat'."
fi
echo ""

# 2. Использование места на диске точками монтирования
echo "2. Использование дискового пространства:"
echo "---------------------------------------"
df -h | sort -k5 -hr
echo ""

# 3. Поиск процессов, ведущих активную дисковую деятельность
# Используем pidstat, если доступен
echo "3. Процессы с активной дисковой нагрузкой (KB/sec):"
echo "--------------------------------------------------"
if command -v pidstat &> /dev/null; then
    pidstat -dl 1 1 | sort -k6 -nr | head -15
else
    echo "Утилита 'pidstat' не установлена. Установите пакет 'sysstat'."
    echo "Альтернатива: использование /proc//io (более сложный парсинг)."
fi
echo ""

# 4. Поиск процессов, удерживающих открытыми много файловых дескрипторов
# Это может указывать на утечку дескрипторов или на процесс, работающий с огромным количеством файлов
echo "4. Первые 10 процессов по количеству открытых файловых дескрипторов:"
echo "---------------------------------------------------------------"
for pid in $(ps -eo pid --no-headers); do
    if [ -d /proc/$pid/fd ]; then
        fd_count=$(ls -1 /proc/$pid/fd 2>/dev/null | wc -l)
        proc_name=$(ps -p $pid -o comm= 2>/dev/null)
        if [ -n "$proc_name" ]; then
            echo "PID: $pid, Имя: $proc_name, FD: $fd_count"
        fi
    fi
done | sort -t',' -k3 -nr | head -10
echo ""

# 5. Поиск больших файлов в открытых дескрипторах
# Может помочь найти процесс, который ведет запись в огромный лог или временный файл
echo "5. Процессы с открытыми большими файлами (&gt;100MB):"
echo "-------------------------------------------------"
for pid in $(ps -eo pid --no-headers); do
    if [ -d /proc/$pid/fd ]; then
        for fd in /proc/$pid/fd/*; do
            file_size=$(stat -Lc%s "$fd" 2>/dev/null)
            if [ -n "$file_size" ] && [ "$file_size" -gt 104857600 ]; then # 100MB в байтах
                file_name=$(readlink -f "$fd" 2>/dev/null)
                proc_name=$(ps -p $pid -o comm= 2>/dev/null)
                file_size_mb=$((file_size / 1024 / 1024))
                echo "PID: $pid, Процесс: $proc_name, Файл: $file_name, Размер: ~$file_size_mb MB"
            fi
        done
    fi
done