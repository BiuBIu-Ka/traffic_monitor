#!/bin/bash

# 获取当前脚本的绝对路径
SCRIPT_PATH=$(realpath "$0")

# 保存流量数据的文件
TRAFFIC_FILE="/root/network_traffic/network_traffic.dat"
LOG_FILE="/root/network_traffic/network_traffic_monitor.log"
CURRENT_MONTH=$(date +"%Y-%m")
SHUTDOWN_THRESHOLD=$((19 * 1024 * 1024 * 1024 + 512 * 1024 * 1024))  # 9.5GB 转换为字节的整数表示

# 要监控的网络接口
INTERFACE="eth0"

# 定义日志记录函数
log_message() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> $LOG_FILE
}

# 初始化日志文件
if [ ! -f $LOG_FILE ]; then
    touch $LOG_FILE
    log_message "日志文件创建成功"
fi

# 如果流量文件不存在或者月份不同，则创建并初始化
if [ ! -f $TRAFFIC_FILE ]; then
    echo "$CURRENT_MONTH 0 0 0" > $TRAFFIC_FILE
    log_message "流量文件创建成功"
else
    saved_month=$(awk '{print $1}' $TRAFFIC_FILE)
    if [ "$saved_month" != "$CURRENT_MONTH" ]; then
        echo "$CURRENT_MONTH 0 0 0" > $TRAFFIC_FILE
        log_message "流量文件月份更新"
    fi
fi

# 读取之前的流量记录
read saved_month last_total_in last_total_out last_check_in last_check_out < $TRAFFIC_FILE

# 获取当前接收和发送的字节数
if ! in_bytes=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes); then
    log_message "无法读取接收字节数"
    exit 1
fi

if ! out_bytes=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes); then
    log_message "无法读取发送字节数"
    exit 1
fi

# 如果上次检查值大于当前值，说明流量可能已被重置
if [ "$in_bytes" -lt "$last_check_in" ] || [ "$out_bytes" -lt "$last_check_out" ]; then
    log_message "检测到网卡流量重置，恢复累积流量"
    last_check_in=0
    last_check_out=0
fi

# 计算增量流量
delta_in=$((in_bytes - last_check_in))
delta_out=$((out_bytes - last_check_out))

# 计算启动前后的累计流量
total_in=$((last_total_in + delta_in))
total_out=$((last_total_out + delta_out))
total_bytes=$((total_in + total_out))

# 检查是否达到9.5GB的阈值
if [ "$total_bytes" -ge "$SHUTDOWN_THRESHOLD" ]; then
    log_message "总流量已达到 19GB，系统即将关机..."
    sudo shutdown -h now
fi

# 自适应单位输出
if [ $total_bytes -lt 1024 ]; then
    total="$total_bytes bytes"
elif [ $total_bytes -lt $((1024 * 1024)) ]; then
    total=$(echo "scale=2; $total_bytes / 1024" | bc)
    total="$total KB"
elif [ $total_bytes -lt $((1024 * 1024 * 1024)) ]; then
    total=$(echo "scale=2; $total_bytes / 1024 / 1024" | bc)
    total="$total MB"
else
    total=$(echo "scale=2; $total_bytes / 1024 / 1024 / 1024" | bc)
    total="$total GB"
fi

# 输出结果
log_message "In+Out Total This Month: $total"
echo "In+Out Total This Month: $total"
echo "------------------------------"

# 将当前流量值保存到文件
echo "$CURRENT_MONTH $total_in $total_out $in_bytes $out_bytes" > $TRAFFIC_FILE

# 检查是否已经存在cron任务
CRON_CMD="*/1 * * * * $SCRIPT_PATH"
(crontab -l | grep -F "$CRON_CMD") || {
    # 尝试添加cron任务，并捕获错误
    if (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab - 2>/tmp/cron_error.log; then
        log_message "定时任务添加成功"
    else
        log_message "无法添加定时任务"
        if grep -q "you are not allowed to use this program" /tmp/cron_error.log; then
            log_message "添加定时任务失败：没有权限"
        elif grep -q "permission denied" /tmp/cron_error.log; then
            log_message "添加定时任务失败：权限被拒绝"
        fi
        rm -f /tmp/cron_error.log
    fi
}
