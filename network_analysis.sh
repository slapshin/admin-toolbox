#!/bin/bash

# source: https://habr.com/ru/articles/953860/

echo "=== Анализ сетевых соединений и трафика ==="
echo "Временная метка: $(date)"
echo ""

# 1. Статистика по сетевым интерфейсам
echo "1. Статистика по сетевым интерфейсам:"
echo "------------------------------------"
if command -v ip &> /dev/null; then
    ip -s link
else
    netstat -i
fi
echo ""

# 2. Сводка по установленным соединениям
echo "2. Количество соединений по состояниям:"
echo "--------------------------------------"
netstat -tun | awk '/^tcp/ {state[$6]++} END {
  for (s in state) print s, state[s]
}' | sort -rn -k2
echo ""

# 3. Процессы, имеющие много сетевых соединений
echo "3. Первые 10 процессов по количеству сетевых соединений:"
echo "---------------------------------------------------"
netstat -tunp 2>/dev/null | awk '$6=="ESTABLISHED"{print $7}' | cut -d'/' -f1 | sort | uniq -c | sort -rn | head -10 | while read count pid; do
    if [ -n "$pid" ] && [ "$pid" != "-" ]; then
        proc_name=$(ps -p $pid -o comm= 2>/dev/null)
        echo "Соединений: $count, PID: $pid, Процесс: $proc_name"
    fi
done
echo ""

# 4. Поиск процессов, слушающих нестандартные порты
echo "4. Слушающие порты (исключая стандартные 22, 80, 443, 5432 и т.д.):"
echo "------------------------------------------------------------------"
netstat -tunlp | grep LISTEN | while read line; do
    port=$(echo $line | awk '{print $4}' | awk -F: '{print $NF}')
    pid_program=$(echo $line | awk '{print $7}')
    # Исключаем некоторые стандартные порты
    if [[ "$port" =~ ^(22|80|443|53|25|587|993|995|5432|3306|27017|11211|6379)$ ]]; then
        continue
    fi
    pid=$(echo $pid_program | cut -d'/' -f1)
    program=$(echo $pid_program | cut -d'/' -f2-)
    echo "Порт: $port, PID: $pid, Процесс: $program"
done
echo ""

# 5. Мониторинг сетевых ошибок и отброшенных пакетов
echo "5. Статистика сетевых ошибок и отбросов:"
echo "---------------------------------------"
if command -v ip &> /dev/null; then
    echo "Интерфейс    | Ошибки(RX/TX) | Сбросы(RX/TX)"
    echo "-------------|---------------|--------------"
    ip -s link show | awk '
    /^[0-9]+:/ {iface=$2; getline}
    /RX.*bytes/ {getline; rx_err=$2; tx_err=$10; getline; rx_drop=$2; tx_drop=$10;
    printf "%-12s | %-13s | %-12s\n", iface, rx_err"/"tx_err, rx_drop"/"tx_drop}'
else
    netstat -i | awk 'NR>2 {print $1, $5"/"$9, $6"/"$10}'
fi