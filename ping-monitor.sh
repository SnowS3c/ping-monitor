#!/bin/bash

# tmux detach-client , sale de la sesion pero sin cerrarla.

# Comprobar que se ejecuta como adminístrador
! [ $(id -u) -eq 0 ] && echo "Se necesitan permisos de adminístrador" && exit 1

########################
# VARIABLES GLOBALES
########################
ips=()
macs=()
log_file="/var/log/ping-monitor.log"
Cl_end="\e[0m"  # Color normal
Cl_r="\e[31m"   # Color rojo
Cl_v="\e[32m"   # Color verde
Cl_m="\e[33m"   # Color marron
Cl_a="\e[34m"   # Color azul
Cl_p="\e[35m"   # Color morado
Cl_c="\e[36m"   # Color cyan
colores=($Cl_v $Cl_m $Cl_a $Cl_p $Cl_c)


export log_file
export Cl_end
export Cl_r
export Cl_v
export Cl_m
export Cl_a
export Cl_p
export Cl_c




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
    color="$2"
    icmp_last=0
    error=1 # 1: falso  0: verdadero
    no_error_count=0
    while read -r linea; do
        [[ "$linea" =~ ^PING ]] && continue   # Para saltar la primera línea
        icmp=$(echo "$linea" | cut -d" " -f 5 | cut -d"=" -f2)

        # Ping correcto
        if [[ "$linea" =~ "64 bytes" ]] && [[ "$icmp" -eq $((icmp_last+1)) ]]; then
            echo -en "[\\${color}${ip}${Cl_end}]"

            # Si esta en modo de error.
            [ "$error" -eq 0 ] && echo -en "${Cl_r}" && ((no_error_count++))

            # Si lleva 30 pings seguidos sin error.
            [ "$no_error_count" -eq 30 ] && echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Error Fin Máquina $ip" >> "$log_file" && error=1 && no_error_count=0
            echo -e "$linea${Cl_end}"

        # Ping incorrecto
        else
            #echo -e "[${Cl_r}${ip}${Cl_end}] ${Cl_r}$linea${Cl_end}"
            echo -e "[\\${color}${ip}${Cl_end}] ${Cl_r}$linea${Cl_end}"
            no_error_count=0
            # Si no estaba en modo de error.
            [ "$error" -eq 1 ] && echo "[$(date +%Y-%m-%d\ %H:%M:%S)] Error Inicio Máquina $ip" >> "$log_file" && error=0
        fi

        icmp_last="$icmp"

        #read -t 0.5 -n 1 ans
        #echo "ANS: $ans"
        #[ "$ans" = q ] && tmux detach-client

    done < <(ping -O "$ip")&
    while read -s -n 1 ans; do
        [[ "$ans" = @("q"|"") ]] && tmux kill-session -t ping-session
    done
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
tmux new-session -s ping-session -d
i=0
for ip in "${ips[@]}"; do
    color=${colores[$i]}
    ((i++))
    tmux send-keys "ping_ip $ip $color" C-m
    tmux split-window -h -t ping-session
done
tmux send-keys "exit" C-m
tmux select-layout even-horizonal    # No rula
tmux attach-session -t ping-session


