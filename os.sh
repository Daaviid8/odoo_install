#!/bin/bash

# Script para verificar sistema operativo y hardware para instalación de Odoo
# Genera recomendaciones en formato JSON

# Función para detectar el sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "$NAME $VERSION_ID"
        else
            echo "Linux (distribución desconocida)"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS $(sw_vers -productVersion)"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        echo "Windows"
    else
        echo "Sistema operativo desconocido: $OSTYPE"
    fi
}

# Función para obtener información de CPU
get_cpu_info() {
    if command -v lscpu &> /dev/null; then
        cores=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
        model=$(lscpu | grep "Model name:" | sed 's/Model name:[[:space:]]*//')
    elif command -v sysctl &> /dev/null; then
        # macOS
        cores=$(sysctl -n hw.ncpu)
        model=$(sysctl -n machdep.cpu.brand_string)
    elif command -v wmic &> /dev/null; then
        # Windows
        cores=$(wmic cpu get NumberOfCores /value | grep -o '[0-9]*')
        model=$(wmic cpu get name /value | grep -o 'Name=.*' | cut -d'=' -f2)
    else
        cores="desconocido"
        model="desconocido"
    fi
    
    echo "$cores|$model"
}

# Función para obtener información de RAM
get_ram_info() {
    if [ -f /proc/meminfo ]; then
        # Linux
        ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        ram_gb=$((ram_kb / 1024 / 1024))
    elif command -v sysctl &> /dev/null; then
        # macOS
        ram_bytes=$(sysctl -n hw.memsize)
        ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
    elif command -v wmic &> /dev/null; then
        # Windows
        ram_bytes=$(wmic computersystem get TotalPhysicalMemory /value | grep -o '[0-9]*')
        ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
    else
        ram_gb="desconocido"
    fi
    
    echo "$ram_gb"
}

# Función para obtener información de almacenamiento
get_storage_info() {
    if command -v df &> /dev/null; then
        # Linux/macOS
        storage_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
        # Verificar si es SSD (Linux)
        is_ssd="desconocido"
        if [ -f /sys/block/sda/queue/rotational ]; then
            if [ "$(cat /sys/block/sda/queue/rotational)" = "0" ]; then
                is_ssd="SSD"
            else
                is_ssd="HDD"
            fi
        fi
    elif command -v wmic &> /dev/null; then
        # Windows
        storage_bytes=$(wmic logicaldisk where size!=null get size /value | grep -o '[0-9]*' | head -1)
        storage_gb=$((storage_bytes / 1024 / 1024 / 1024))
        is_ssd="desconocido"
    else
        storage_gb="desconocido"
        is_ssd="desconocido"
    fi
    
    echo "$storage_gb|$is_ssd"
}

# Función para determinar la categoría de usuarios
determine_user_category() {
    local cpu_cores=$1
    local ram_gb=$2
    local storage_gb=$3
    
    if [[ $cpu_cores -ge 8 && $ram_gb -ge 32 && $storage_gb -ge 50 ]]; then
        echo "mas_de_50"
    elif [[ $cpu_cores -ge 4 && $ram_gb -ge 4 && $storage_gb -ge 20 ]]; then
        echo "hasta_50"
    elif [[ $cpu_cores -ge 2 && $ram_gb -ge 2 && $storage_gb -ge 10 ]]; then
        echo "hasta_10"
    else
        echo "insuficiente"
    fi
}

# Función para generar recomendaciones
generate_recommendations() {
    local os=$1
    local category=$2
    local cpu_cores=$3
    local ram_gb=$4
    local storage_gb=$5
    
    local install_method=""
    local requirements=""
    local notes=""
    local web_option=false
    
    # Determinar método de instalación según el OS
    if [[ $os == *"Ubuntu"* || $os == *"Debian"* || $os == *"CentOS"* || $os == *"Red Hat"* ]]; then
        install_method="nativo"
        requirements="sudo apt update && sudo apt install -y python3 python3-pip postgresql postgresql-contrib nginx git"
    elif [[ $os == *"Windows"* ]]; then
        install_method="wsl"
        requirements="Instalar WSL2 con Ubuntu, luego ejecutar: sudo apt update && sudo apt install -y python3 python3-pip postgresql postgresql-contrib nginx git"
    elif [[ $os == *"macOS"* ]]; then
        install_method="docker"
        requirements="Instalar Docker Desktop, luego usar: docker-compose up con configuración de Odoo"
    else
        install_method="web"
        web_option=true
        requirements="Sistema no compatible para instalación local"
    fi
    
    # Ajustar recomendaciones según la categoría
    case $category in
        "hasta_10")
            notes="Configuración básica para hasta 10 usuarios. SSD recomendado para mejor rendimiento."
            ;;
        "hasta_50")
            notes="Configuración intermedia para hasta 50 usuarios. SSD altamente recomendado."
            ;;
        "mas_de_50")
            notes="Configuración empresarial para más de 50 usuarios. Considerar separar aplicación y base de datos en servidores diferentes."
            ;;
        "insuficiente")
            install_method="web"
            web_option=true
            requirements="Hardware insuficiente para instalación local"
            notes="Se recomienda usar Odoo Online o actualizar hardware"
            ;;
    esac
    
    echo "$install_method|$requirements|$notes|$web_option"
}

# Main execution
echo "Analizando sistema para instalación de Odoo..."

# Recopilar información del sistema
os=$(detect_os)
cpu_info=$(get_cpu_info)
cpu_cores=$(echo $cpu_info | cut -d'|' -f1)
cpu_model=$(echo $cpu_info | cut -d'|' -f2)
ram_gb=$(get_ram_info)
storage_info=$(get_storage_info)
storage_gb=$(echo $storage_info | cut -d'|' -f1)
storage_type=$(echo $storage_info | cut -d'|' -f2)

# Determinar categoría y recomendaciones
category=$(determine_user_category $cpu_cores $ram_gb $storage_gb)
recommendations=$(generate_recommendations "$os" "$category" $cpu_cores $ram_gb $storage_gb)

install_method=$(echo $recommendations | cut -d'|' -f1)
requirements=$(echo $recommendations | cut -d'|' -f2)
notes=$(echo $recommendations | cut -d'|' -f3)
web_option=$(echo $recommendations | cut -d'|' -f4)

# Generar JSON
cat << EOF > odoo_system_analysis.json
{
  "fecha_analisis": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sistema_operativo": {
    "nombre": "$os",
    "compatible": $([ "$install_method" != "web" ] && echo "true" || echo "false")
  },
  "hardware": {
    "cpu": {
      "nucleos": $cpu_cores,
      "modelo": "$cpu_model"
    },
    "ram_gb": $ram_gb,
    "almacenamiento": {
      "espacio_libre_gb": $storage_gb,
      "tipo": "$storage_type"
    }
  },
  "categoria_usuarios": "$category",
  "requisitos_minimos": {
    "hasta_10": {
      "cpu_nucleos": 2,
      "ram_gb": 2,
      "almacenamiento_gb": 10
    },
    "hasta_50": {
      "cpu_nucleos": 4,
      "ram_gb": 4,
      "almacenamiento_gb": 20
    },
    "mas_de_50": {
      "cpu_nucleos": 8,
      "ram_gb": 32,
      "almacenamiento_gb": 50
    }
  },
  "recomendacion_instalacion": {
    "metodo": "$install_method",
    "requiere_wsl": $([ "$install_method" = "wsl" ] && echo "true" || echo "false"),
    "usar_web": $web_option,
    "comandos_instalacion": "$requirements",
    "notas": "$notes"
  },
  "configuracion_web": {
    "necesaria": $web_option,
    "url_sugerida": "https://www.odoo.com/es_ES/trial",
    "credenciales": {
      "usuario": "admin",
      "contraseña": "generar_durante_registro"
    }
  },
  "cumple_requisitos": {
    "cpu": $([ $cpu_cores -ge 2 ] && echo "true" || echo "false"),
    "ram": $([ $ram_gb -ge 2 ] && echo "true" || echo "false"),
    "almacenamiento": $([ $storage_gb -ge 10 ] && echo "true" || echo "false"),
    "os": $([ "$install_method" != "web" ] && echo "true" || echo "false")
  }
}
EOF

echo "Análisis completado. Archivo JSON generado: odoo_system_analysis.json"
echo ""
echo "Resumen:"
echo "- Sistema: $os"
echo "- CPU: $cpu_cores núcleos ($cpu_model)"
echo "- RAM: ${ram_gb}GB"
echo "- Almacenamiento: ${storage_gb}GB ($storage_type)"
echo "- Categoría: $category"
echo "- Método de instalación: $install_method"

if [ "$web_option" = "true" ]; then
    echo ""
    echo "⚠️  RECOMENDACIÓN: Usar Odoo Web debido a limitaciones de hardware o SO"
    echo "   URL: https://www.odoo.com/es_ES/trial"
    echo "   Crear cuenta con usuario y contraseña personalizada"
fi

# Mostrar el JSON generado
echo ""
echo "Contenido del JSON generado:"
cat odoo_system_analysis.json
