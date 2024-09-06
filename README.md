## 流量阈值 自动关机
一个针对具有流量限制服务器写的脚本，在超出给定的流量后服务器自动关机！

已优化的问题：

 1. 优化脚本运行多次会一直叠加流量的问题 
 2. 优化服务器重启后流量记录值清空的问题 
 3. 增加一个小日志系统

运行：
```bash
wget https://raw.githubusercontent.com/BiuBIu-Ka/traffic_monitor/main/main.sh && chmod 777 main.sh &&  ./main.sh 
```
