#!/bin/bash

# meter comando tmux dentro de la función ping_ip
# tmux detach-client , sale de la sesion pero sin cerrarla.


# Comprobar que se ejecuta como adminístrador
! [ $(id -u) -eq 0 ] && echo "Se necesitan permisos de adminístrador" && exit 1

########################
# VARIABLES GLOBALES
########################
ips=()
macs=()
log_file="/var/log/ping-monitor.log"
Cl_v="\e[32m"   # Color verde
Cl_r="\e[31m"   # Color rojo
Cl_end="\e[0m"  # Color normal

export log_file
export Cl_v
export Cl_r
export Cl_end

########################
#   FUNCIONES
########################

# Funcion para obtener las ips y almacenarlas en el array ips
function obtener_ips(){
    echo -n "Buscando macs..."
    arp_table=$(arp-scan --interface "$interfaz" -l)
    for id in "${!macs[@]}"; do
        ip=$(echo "$arp_table" | grep -i "${macs[$id]}" | awk {' print $1 '})
        [ "$ip" ] && ips["$id"]="$ip"
    done
    echo "Hecho!"
}


# Funcion que realiza el ping
function ping_ip(){
    ip="$1"
    icmp_last=0
    error=1 # 1: falso  0: verdadero
    no_error_count=0
    while read -r linea; do
        [[ "$linea" =~ ^PING ]] && continue   # Para saltar la primera línea
        icmp=$(echo "$linea" | cut -d" " -f 5 | cut -d"=" -f2)

        # Ping correcto
        if [[ "$linea" =~ "64 bytes" ]]; then
            echo -en "[${Cl_v}${ip}${Cl_end}]"
            [ "$error" -eq 0 ] && echo -en "${Cl_r}" && ((no_error_count++))
            [ "$no_error_count" -eq 30 ] && echo "Error Fin [$(date +%Y-%m-%d\ %H:%M:%S)] Máquina $ip" >> "$log_file" && error=1 && no_error_count=0
            echo -e "$linea${Cl_end}"

        # Ping incorrecto
        elif [[ "$linea" =~ "no answer" ]] || [[ "$linea" =~ "Unreachable" ]] || [[ "$icmp" -ne $((icmp_last+1)) ]]; then
            echo -e "[${Cl_r}${ip}${Cl_end}] ${Cl_r}$linea${Cl_end}"

            [ "$error" -eq 1 ] && echo "Error Inicio [$(date +%Y-%m-%d\ %H:%M:%S)] Máquina $ip" >> "$log_file" && error=0
        fi
#        echo "icmp: $icmp   last_icmp: $icmp_last"
        icmp_last="$icmp"
    done < <(ping -O "$ip")
}
export -f ping_ip


##############################
# COMPROBACIÓN DE PARÁMETROS
##############################
[ -n "$1" ] && ip a | egrep "$1:" &>/dev/null && interfaz="$1" || { echo "Error: La interfaz no existe"; exit 2 ; }
params=("${@,,}")


# Comprobar las macs introducidas y almacenarlas en el array macs
for mac in "${params[@]:1}"; do
    # Comprobar si la mac tiene un formato válido.
    [[ "$mac" =~ ^(([0-9a-f]){2}:){5}([0-9a-f]){2}$ ]] && macs+=("$mac") || { echo "Error: MAC $mac no tiene un formato adecuado"; exit 3; }
done


# INICIALIZANDO
obtener_ips
tmux new-session -s prueba -d
for ip in "${ips[@]}"; do
    tmux send-keys "ping_ip $ip" C-m
#    ping_ip "$ip"
done
tmux attach-session -t prueba
#tmux select-layout even-horizonal
#for id in "${!macs[@]}"; do
#    echo "mac: ${macs[$id]} ip: ${ips[$id]}"
#done

