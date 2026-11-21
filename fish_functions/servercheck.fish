=== servercheck.fish ===
function servercheck --description 'Visar realtidsstatus för tjänster, minne, CPU/GPU-viloläge, temperatur och effekt på BC-250'
    if test "$argv[1]" != "--render"
        if test "$argv[1]" = "once"
            servercheck --render
        else
            watch -n 1 -t "fish -c 'servercheck --render'"
        end
        return
    end
    
    echo "=== 1. Tjänster (Tailscale / llama-server / rag-mcp / Governor) ==="
    for svc in tailscaled llama-server rag-mcp cyan-skillfish-governor-smu
        echo "$svc: "(systemctl is-active $svc)
    end
    
    echo -e "\n=== 2. Tailscale-API (Port 8081 & 8005) ==="
    set -l ts_ip (tailscale ip -4 2>/dev/null)
    if test -n "$ts_ip"
        echo "LLM Endpoint: http://$ts_ip:8081/v1"
        echo "RAG Endpoint: http://$ts_ip:8005/sse"
    else
        echo "Tailscale IP: Ej ansluten"
    end
    ss -tlnp | grep -E "8081|8005" || echo "Port 8081/8005 lyssnar INTE"
    
    echo -e "\n=== 3. RAM, GPU-GTT & Aktiv modell ==="
    free -h | grep -E "Mem:|Swap:"
    set -l gtt_used (cat /sys/class/drm/card*/device/mem_info_gtt_used 2>/dev/null | head -n 1)
    if test -n "$gtt_used"
        printf "GPU GTT använt: %.2f GiB\n" (math "$gtt_used / 1073741824")
    end
    set -l rss_kb (ps -o rss= -C llama-server 2>/dev/null | awk '{s+=$1} END {print s+0}')
    printf "llama-server RAM (RSS): %.0f MiB\n" (math "$rss_kb / 1024")
    set -l model_id (curl -sf http://100.95.138.9:8081/v1/models | grep -o '"id":"[^"]*"' | head -n 1)
    if test -n "$model_id"
        echo "Laddad modell: $model_id"
    else
        echo "Laddad modell: Ingen (avlastad)"
    end
    
    echo -e "\n=== 4. CPU- & GPU-viloläge, Temperatur & Effekt (Realtid) ==="
    set -l gov_min (busctl get-property com.cyanskillfish.Governor /com/cyanskillfish/Governor/Range/Current com.cyanskillfish.Governor.Range Min 2>/dev/null | awk '{print $2}')
    set -l gov_max (busctl get-property com.cyanskillfish.Governor /com/cyanskillfish/Governor/Range/Current com.cyanskillfish.Governor.Range Max 2>/dev/null | awk '{print $2}')
    if test -n "$gov_min" -a -n "$gov_max"
        echo "Governor-intervall: $gov_min – $gov_max MHz"
    end
    
    set -l is_proc (curl -sf http://100.95.138.9:8081/slots 2>/dev/null | grep -o '"is_processing":[^,]*' | head -n 1 | cut -d: -f2)
    if test "$is_proc" = "true"
        echo "GPU-läge:           AKTIV Boost (upp till $gov_max MHz)"
    else if test "$is_proc" = "false"
        echo "GPU-läge:           Standby ($gov_min MHz, modell laddad)"
    else
        echo "GPU-läge:           Lägsta viloläge ($gov_min MHz, avlastad)"
    end
    
    set -l cpu_med (cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | sort -n | awk '{a[NR]=$1} END {if(NR>0) printf "%.0f", a[int((NR+1)/2)]/1000}')
    if test -n "$cpu_med"
        if test "$cpu_med" -le 1300
            echo "CPU-läge:           Lägsta viloläge (median $cpu_med MHz, djup C3-vila)"
        else
            echo "CPU-läge:           Aktiv last (median $cpu_med MHz)"
        end
    end
    
    sensors 2>/dev/null | grep -E "edge:|junction:|mem:|PPT:|fan"
end
