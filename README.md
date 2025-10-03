# 🚀 Proyecto de Monitoreo de Bases de Datos

Sistema modular para generar reportes de salud de bases de datos SQL Server usando PowerShell y dbatools.

## 📁 Estructura del Proyecto
DBAToolsProyecto/
├── src/
│ ├── main.ps1 # Script principal
│ ├── modules/
│ │ ├── dbatools-functions.ps1 # Funciones de dbatools
│ │ ├── data-collector.ps1 # Procesamiento de datos
│ │ └── html-generator.ps1 # Generación de HTML
│ └── templates/
│ ├── base-template.html # Template base
│ └── styles.css # Estilos CSS
├── config/
│ └── settings.json # Configuración
├── reports/ # Reportes generados
└── README.md


## 🛠️ Requisitos

- PowerShell 5.1 o superior
- Módulo dbatools
- SQL Server (cualquier versión compatible)

## 🚀 Instalación

1. **Clonar o descargar el proyecto**
2. **Instalar dbatools:**
   ```powershell
   Install-Module -Name dbatools -Scope CurrentUser -Force