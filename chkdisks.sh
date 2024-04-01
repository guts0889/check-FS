#!/bin/bash
#Rev9

R='\033[0;31m'  #Rojo
V='\033[0;32m'  #Verde
AM='\033[1;33m' #Amarillo
AZ='\033[0;34m' #Azul
MM='\033[1;35m' #Magenta
S='\033[0m'     #Quita color

#Comprueba que el script tiene todos los argumentos necesarios para funcionar.
if [ "$#" -ne 2 ]; then
    echo -e "${MM}Uso: $0 [Porcentaje de uso mínimo 0-100] [Número de lineas a mostrar]${S}"
    exit 1
fi

#Comprueba que el primer argumento esta bien escrito.
if ! [[ $1 =~ ^[0-9]+$ ]] || [ "$1" -lt 0 ] || [ "$1" -gt 100 ]; then
    echo -e "${MM}El primer argumento debe ser un porcentaje de uso mínimo entre 0 y 100.${S}"
    exit 1
fi

#Comprueba que el segundo argumento esta bien escrito.
if ! [[ $2 =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
    echo -e "${MM}El segundo argumento debe ser un número positivo que indica cuántos archivos mostrar.${S}"
    exit 1
fi

#Variables que se asgignan a los valores dados al lanzar el script.
porcentaje=$1
nlineas=$2
encontrado=0

#Se saca informacion de la salida del comando 'df' para luego asignarla a las variables pertinentes
#y sacar la informacion necesaria con 'awk'.
df -h | grep -vE '^Filesystem|tmpfs|devtmpfs' | while read -r line; do

uso=$(echo $line | awk '{print $5}' | sed 's/%//g')
libre=$(echo $line | awk '{print $4}')
enuso=$(echo $line | awk '{print $3}')
particion=$(echo $line | awk '{print $6}')

#Comprueba que discos/fs/particiones coinciden con el valor dado al lanzar el script y lo imprime por pantalla.
if [ $uso -ge "$porcentaje" ]; then
    encontrado=1
    #Imprime por pantalla la informacion del disco si encuentra coincidencia con el % dado.
    echo "______________________________________________________________________________________"
    echo ""
    echo -e "Particion: $particion"
    echo -e "Uso: ${R}$uso%${S}"
    echo -e "Libre: ${V}$libre${S}"
    echo -e "Se usa: ${AM}$enuso${S}"
    echo ""
    #Pasa a una variable la salida del comando 'find' ordenado y con el numero de lineas que le ha dado el usuario
    archivos_pesados=$(find $particion -type f 2>/dev/null -exec du -h {} + | sort -rh | head -n $nlineas)
    #Formatea la salida del comando 'find' para guardar en la varibale la ruta absoluta de cada archivo
    archivos_pesados_proc=$(find $particion -type f 2>/dev/null -exec du -h {} + | sort -rh | head -n $nlineas | awk -F'\t' '{print $2}')
    echo -e "${AZ}Los archivos mas grandes son:${S}"
    echo "$archivos_pesados"
        #Comprueba si los archivos que ha detectado estan siendo usados por algun proceso
        for archivo in $archivos_pesados_proc; do
            if lsof "$archivo" > /dev/null; then
                echo -e "${R}El archivo $archivo está siendo utilizado.${S}"
            fi
        done
        IFS=$'\n' #<-- Hace que no se tengan en cuenta los espacios como separador por si el nombre del archivo los tiene.
        # Pregunta al usuario que quiere hacer con los archivos encontrados
        echo -e "${AM}Que quieres hacer? [C]omprimr [B]orrar/[V]aciar [N]ada${S}"
        #Espera el input del usuario
        read -r respuesta_comprimir </dev/tty
        case "$respuesta_comprimir" in
        # Dependiendo de la eleccion se metera en un caso diferente
            [Cc]* ) #<-- Pongo mayusculas y minusculas para que no sea case sensitive, asi con todos los casos
                fecha_actual=$(date +"%Y-%m-%d_%H-%M-%S")
                nombre_archivo_comprimido="archivos_pesados_$fecha_actual.tar.gz"
                archivos_a_comprimir=()
                # Pregunta archivo por archivo si se desea comprimir
                for archivo in $archivos_pesados_proc; do
                    echo -e "${AM}Comprimir ${MM}$archivo${AM}? [S]í/[N]o${S}"
                    read -r comprimir_archivo </dev/tty
                    if [[ $comprimir_archivo =~ ^[SsYy]$ ]]; then
                        archivos_a_comprimir+=("$archivo")
                    fi
                done
                # Comprime los archivos seleccionados
                tar -czvf "$nombre_archivo_comprimido" "${archivos_a_comprimir[@]}" 2>/dev/null
                echo -e "${V}Archivos comprimidos en $nombre_archivo_comprimido${S}"
                # Pregunta si se quieren borrar solo los archivos comprimidos
                echo -e "${AM}[B]orrar [V]aciar archivos compresos o no hacer [N]ada?${S}"
                read -r borrar_archivos_comprimidos </dev/tty
                if [[ $borrar_archivos_comprimidos =~ ^[Bb]$ ]]; then
                    for archivo in "${archivos_a_comprimir[@]}"; do
                        rm -f "$archivo"
                        echo -e "${R}Borrado: $archivo${S}"
                    done
                fi
                if [[ $borrar_archivos_comprimidos =~ ^[Vv]$ ]]; then
                    for archivo in "${archivos_a_comprimir[@]}"; do
                        cat /dev/null > "$archivo"
                        echo -e "${R}Vaciado: $archivo${S}"
                    done
                fi
                ;;
            [BbVv]* )
                #Si se mete en este caso preguntara archivo por archivo si se quiere vaciar o borrar.
                for archivo in $archivos_pesados_proc; do
                    echo -e "${AM}[b]orrar/[v]aciar/[n]ada -- ${MM}$archivo${S}"
                    read -r respuesta </dev/tty
                    case "$respuesta" in
                        [bB]* )
                            echo -e "${R}Borrado: $archivo${S}"
                            rm -f "$archivo"
                            ;;
                        [vV]* )
                            echo -e "${R}Vaciado: $archivo${S}"
                            cat /dev/null > $archivo
                            ;;
                        [nN]* )
                            echo -e "${V}Se deja como esta.${S}"
                            ;;
                        * )
                            echo "No es una opción válida."
                            ;;
                    esac
                done
                ;;
            [Nn]* )
                echo "No se realiza ninguna acción."
                ;;
                * )
                echo "No se realiza ninguna acción."
                ;;
        esac
        unset IFS #<-- Quita la opcion de los espacios para que vuelva a tener el valor normal
    echo -e "${S}"
    echo ""
    #A partir de aqui el codigo es muy parecido a lo que hay con los archivos mas pesados
    echo -e "${AZ}Los archivos menos utilizados son:${S}"
        find $particion -type f -printf '%A@ %p\n' 2>/dev/null | sort -n | head -n $nlineas | while read -r line; do
            access_time=$(echo $line | cut -d' ' -f1)
            file_path=$(echo $line | cut -d' ' -f2-)
            size_mb=$(du -h "$file_path" | cut -f1)
            access_date=$(date -d @$access_time +'%Y-%m-%d')
            printf "%-5s ${MM}%-10s${S} %-10s\n" "$size_mb" "$access_date" "$file_path"
        done
    archivos_menos_usados_proc=$(find $particion -type f -printf '%A@ %p\n' 2>/dev/null | sort -n | head -n $nlineas | awk '{print $2}')
    #Comprueba si los archivos que ha detectado estan siendo usados por algun proceso
        for archivo in $archivos_menos_usados_proc; do
            if lsof "$archivo" > /dev/null; then
                echo -e "${R}El archivo $archivo está siendo utilizado.${S}"
            fi
        done
        IFS=$'\n'
        echo -e "${AM}Que quieres hacer? [C]omprimr [B]orrar/[V]aciar [N]ada${S}"
        read -r respuesta_comprimir </dev/tty
        case "$respuesta_comprimir" in
            [Cc]* )
                fecha_actual=$(date +"%Y-%m-%d_%H-%M-%S")
                nombre_archivo_comprimido="archivos_pesados_$fecha_actual.tar.gz"
                archivos_a_comprimir=()
                # Pregunta archivo por archivo si se desea comprimir
                for archivo in $archivos_pesados_proc; do
                    echo -e "${AM}Comprimir ${MM}$archivo${AM}? [S]í/[N]o${S}"
                    read -r comprimir_archivo </dev/tty
                    if [[ $comprimir_archivo =~ ^[SsYy]$ ]]; then
                        archivos_a_comprimir+=("$archivo")
                    fi
                done
                # Comprime los archivos seleccionados
                tar -czvf "$nombre_archivo_comprimido" "${archivos_a_comprimir[@]}" 2>/dev/null
                echo -e "${V}Archivos comprimidos en $nombre_archivo_comprimido${S}"
                # Pregunta si se quieren borrar solo los archivos comprimidos
                echo -e "${AM}[B]orrar [V]aciar archivos compresos o no hacer [N]ada?${S}"
                read -r borrar_archivos_comprimidos </dev/tty
                if [[ $borrar_archivos_comprimidos =~ ^[Bb]$ ]]; then
                    for archivo in "${archivos_a_comprimir[@]}"; do
                        rm -f "$archivo"
                        echo -e "${R}Borrado: $archivo${S}"
                    done
                fi
                if [[ $borrar_archivos_comprimidos =~ ^[Vv]$ ]]; then
                    for archivo in "${archivos_a_comprimir[@]}"; do
                        cat /dev/null > "$archivo"
                        echo -e "${R}Vaciado: $archivo${S}"
                    done
                fi
                ;;
            [BbVv]* )
                for archivo in $archivos_menos_usados_proc; do
                    echo -e "${AM}[b]orrar/[v]aciar/[n]ada --${MM}$archivo${S}"
                    read -r respuesta </dev/tty
                    case "$respuesta" in
                        [bB]* )
                            echo -e "${R}Borrado: $archivo${S}"
                            rm -f "$archivo"
                            ;;
                        [vV]* )
                            echo -e "${R}Vaciado: $archivo${S}"
                            cat /dev/null > $archivo
                            ;;
                        [nN]* )
                            echo -e "${V}No se borra el archivo.${S}"
                            ;;
                        * )
                            echo "No es una opción válida."
                            ;;
                    esac
                done
                ;;
            [Nn]* )
                echo "No se realiza ninguna acción."
                ;;
                * )
                echo "No se realiza ninguna acción."
                ;;
        esac
        unset IFS
    echo ""
    echo -e "${V}>>>>>Comprobacion de $particion completa<<<<<${S}"
    echo ""
fi

done
if [ $encontrado -eq 0 ]; then
    echo -e "${V}No hay ningún sistema de archivos con un uso igual o superior al ${porcentaje}%.${S}"
fi
