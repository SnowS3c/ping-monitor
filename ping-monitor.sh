#!/bin/bash

#####################
# No es necesario dividir la ventana con tmux como hizo leo pero queda to guapo
######################



# Comprobar que se ejecuta como adminístrador
! [ $(id -u) -eq 0 ] && echo "Se necesitan permisos de adminístrador" && exit 1

########################
# VARIABLES GLOBALES
########################
ips=()
macs=()
log_file="/var/log/ping-monitor.log"



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
function ping_check(){
    ip="$1"
    #ping -O "$ip" >> "$log_file"
# while read -r line; do echo "Linea: $line"; done < <(ping 192.168.100.1)
}




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



obtener_ips
for id in "${!macs[@]}"; do
    echo "mac: ${macs[$id]} ip: ${ips[$id]}"
done

