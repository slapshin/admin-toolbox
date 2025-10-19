#!/bin/bash

# source: https://habr.com/ru/articles/953860/

echo "=== Анализ памяти и процессов-кандидатов на OOM Killer ==="
echo "Временная метка: $(date)"
echo ""

# 1. Общая картина по памяти
echo "1. Сводка по памяти:"
echo "-------------------"
free -h
echo ""

# 2. Детализация по оперативной памяти
echo "2. Детализация использования RAM и Swap:"
echo "----------------------------------------"
cat /proc/meminfo | grep -E "(MemTotal|MemAvailable|SwapTotal|SwapFree|SwapCached)"
echo ""

# 3. Поиск процессов, потребляющих много памяти
# Сортируем по резидентной памяти (RSS), которая реально находится в RAM
echo "3. Первые 10 процессов по использованию резидентной памяти (RSS):"
echo "-------------------------------------------------------------"
ps aux --sort=-%mem | awk 'NR<=11 {printf "%-8s %-6s %-4s %-8s %-8s %s\n", $2, $1, $4, $3, $6/1024" MB", $11}'
echo ""

# 4. Анализ памяти, которая ждет записи на диск
# Это может быть индикатором нагрузки на I/O
echo "4. Процессы с большим объемом ожидающей записи памяти:"
echo "------------------------------------------------------------------"
for pid in $(ps -eo pid --no-headers); do
    if [ -f /proc/$pid/statm ]; then
        dirty_pages=$(grep -i "Private_Dirty:" /proc/$pid/smaps 2>/dev/null | awk '{sum += $2} END {print sum}')
        if [ -n "$dirty_pages" ] && [ "$dirty_pages" -gt 1000 ]; then
            proc_name=$(cat /proc/$pid/comm 2>/dev/null)
            dirty_kb=$((dirty_pages * 4)) # переводим страницы в килобайты (обычно 4KB на страницу)
            echo "PID: $pid, Имя: $proc_name, Грязная память: $dirty_kb KB"
        fi
    fi
done | sort -k6 -nr | head -10
echo ""

# 5. Мониторинг "давления" памяти (PSI - Pressure Stall Information)
# Показывает, сколько времени процессы проводят в ожидании памяти
echo "5. Давление на память (PSI):"
echo "---------------------------"
if [ -f /proc/pressure/memory ]; then
    cat /proc/pressure/memory
else
    echo "Информация о ''давлении'' памяти не поддерживается в этой версии ядра."
fi
echo ""