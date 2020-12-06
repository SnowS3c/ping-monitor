#!/bin/bash

#=====================================================================================
#
#   USO
#   - Teclas Enter y q cierran el programa.
#   - Tecla l muestra el fichero de log. Dentro del fichero pulsar q para salir.
#
#   EJEMPLO
#       bash ping-monitor.sh enp2s0 08:00:27:77:e8:67 08:00:27:99:17:A3 08:00:27:A0:51:6E
#
#=====================================================================================


# Comprobar que se ejecuta como adminístrador
! [ $(id -u) -eq 0 ] && echo "Se necesitan permisos de adminístrador" && exit 1


#=====================================================================================
#
#   VARIABLES GLOBALES
#
#=====================================================================================
ips=()
macs=()
log_file="/var/log/ping-monitor.log"
Cl_end="\e[0m"      # Color normal
Cl_bold="\e[01m"    # Negrita
Cl_r="\e[31m"       # Color rojo
Cl_v="\e[32m"       # Color verde
Cl_m="\e[33m"       # Color marron
Cl_a="\e[34m"       # Color azul
Cl_p="\e[35m"       # Color morado
Cl_c="\e[36m"       # Color cyan
colores=($Cl_v $Cl_m $Cl_a $Cl_p $Cl_c)

export log_file
export Cl_end
export Cl_bold
export Cl_r
export Cl_v
export Cl_m
export Cl_a
export Cl_p
export Cl_c




#=====================================================================================
#   FUNCIÓN obtener_ips
#
#   Función para obtener las ips de cada máquina y almacenarlas en el array ips
#=====================================================================================
function obtener_ips(){
    echo -n "Buscando macs..."
    arp_table=$(arp-scan --interface "$interfaz" -l)
    for id in "${!macs[@]}"; do
        ip=$(echo "$arp_table" | grep -i "${macs[$id]}" | awk {' print $1 '})
        [ "$ip" ] && ips["$id"]="$ip"
    done
    echo "Hecho!"
}


#=====================================================================================
#   FUNCIÓN ping_ip
#
#   Función que ejecuta los pings en segundo plano
#=====================================================================================
function ping_ip(){
    ip="$1"
    mac="$2"
    color="$3"          # Color para mostrar la ip
    icmp_last=0
    error=1             # Para indicar el modo de error -  1: falso  0: verdadero
    no_error_count=0    # Variable que cuenta los pings correctos consecutivos.
    while read -r linea; do
        [[ "$linea" =~ ^PING ]] && sleep 1 && clear && continue   # Para no mostrar la primera línea del PING
        icmp=$(echo "$linea" | cut -d" " -f 5 | cut -d"=" -f2)    # icmp del ping actual

        # En caso de Ping correcto
        if [[ "$linea" =~ ^64\ bytes ]] && [[ "$icmp" -eq $((icmp_last+1)) ]]; then
            echo -en "[\\${color}${ip}${Cl_end}]"

            # Si esta en modo de error muestro el ping en color rojo y sumo 1 al contador de pings sin error.
            [ "$error" -eq 0 ] && echo -en "${Cl_r}" && ((no_error_count++))

            # Si lleva 30 pings seguidos sin error, escribo en el fichero de log el fin del error y modifico el valor de la variable error a 1 y el contador de ping sin errores a 0.
            [ "$no_error_count" -eq 30 ] && echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] [${Cl_bold}\\${color}${mac}${Cl_end}]\t[${Cl_bold}${Cl_r}ERROR FIN${Cl_end}]" >> "$log_file" && error=1 && no_error_count=0


            echo -e "$linea${Cl_end}"

        # En caso de Ping incorrecto
        else
            # Muestro el ping de color rojo
            echo -e "[\\${color}${ip}${Cl_end}] ${Cl_r}$linea${Cl_end}"
            no_error_count=0
            # Si no estaba en modo de error, escribo en el fichero de log la hora del inicio del error y modifico el valor de la variable error a 0 indicando que está en modo de error.
            [ "$error" -eq 1 ] && echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] [${Cl_bold}\\${color}${mac}${Cl_end}]\t[${Cl_bold}ERROR INICIO${Cl_end}]" >> "$log_file" && error=0
        fi

        icmp_last="$icmp"

    done < <(ping -O "$ip")&


    # En caso de pulsar la q o enter, mata la sesion de tmux.
    # En caso de pulsar la l, envía la sesion a segundo plano.
    while read -s -n 1 tecla; do
        [[ "${tecla,,}" = @("q"|"") ]] && tmux kill-session -t ping-session
        [[ "${tecla,,}" = @("l") ]] && tmux detach-client
    done
}

export -f ping_ip




#=====================================================================================
#
#   COMPROBACIÓN DE PARÁMETROS
#
#=====================================================================================
# Compruebo si la interfaz introducida es correcta.
[ -n "$1" ] && ip a | egrep "$1:" &>/dev/null && interfaz="$1" || { echo "Error: La interfaz no existe"; exit 2 ; }

# Guardo todos los parámetros en el array params
params=("${@,,}")

# Compruebo las macs introducidas y las almaceno en el array macs
for mac in "${params[@]:1}"; do
    [[ "$mac" =~ ^(([0-9a-f]){2}:){5}([0-9a-f]){2}$ ]] && macs+=("$mac") || { echo "Error: MAC $mac no tiene un formato adecuado"; exit 3 ; }
done




#=====================================================================================
#
#   INICIALIZANDO
#
#=====================================================================================
obtener_ips
tmux new-session -s ping-session -d     # Creo una sesion de tmux en segundo plano


# Escribo en el fichero de log la fecha y hora de inicio
echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] ###################### INICIO PING ###########################################" >> "$log_file"

i=0 # contador para seleccionar el color de cada ip
for id in "${!ips[@]}"; do
    color=${colores[$i]}
    ((i++))
    tmux send-keys "ping_ip ${ips[$id]} ${macs[$id]} $color" C-m
    tmux split-window -h -t ping-session
done
tmux send-keys "exit" C-m   # Para cerrar la ultima ventana de tmux que se crea y que no muestra nada

sleep 1 # Hay que esperar un poco para que funcione el select-layout
tmux select-layout even-horizontal
tmux attach-session -t ping-session

# En caso de que se envie la sesion de tmux a segundo plano muestro el fichero de log.
# Este bucle se ejecuta hasta que se cierra la sesion de tmux
while tmux list-session | grep ping-session &> /dev/null; do
    less -R +G "$log_file"
    tmux attach-session -t ping-session
done

# Marco en el fichero de log el final del ping
echo -e "####################################################################################################\n\n" >> "$log_file"
