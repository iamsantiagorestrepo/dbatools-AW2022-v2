# Proyecto de Monitoreo de Bases de Datos

Sistema modular para generar reportes de salud de bases de datos **SQL Server**, usando **PowerShell** junto con el módulo **dbatools**.

---

## 📂 Estructura del Proyecto

dbatools-AW2022-v2/
├── src/
│ ├── main.ps1
│ └── modules/
│ ├── dbatools-functions.ps1
│ ├── data-collector.ps1
│ └── html-generator.ps1
│ └── templates/
│ ├── base-template.html
│ └── styles.css
├── config/
│ └── settings.json
├── reports/ ← Directorio donde se guardan los reportes generados
└── README.md

yaml
Copy code

---

## ✅ Requisitos

- PowerShell 5.1 o versión superior
- Módulo **dbatools** instalado
- Acceso a instancias de **SQL Server** compatibles

---

## 🛠 Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/iamsantiagorestrepo/dbatools-AW2022-v2.git
   cd dbatools-AW2022-v2
Instala el módulo dbatools (si aún no lo tienes):

powershell
Copy code
Install-Module -Name dbatools -Scope CurrentUser -Force
🚀 Uso / Ejecución
Ajusta el archivo config/settings.json con tus credenciales, nombres de instancias, parámetros que quieras monitorear, etc.

Ejecuta el script principal:

powershell
Copy code
.\src\main.ps1
El sistema hará lo siguiente:

Usará los módulos en src/modules/ para recolectar datos de SQL Server

Generará un reporte HTML usando la plantilla en src/templates/

Guardará el reporte en la carpeta reports/

📋 Ejemplo de “settings.json”
json
Copy code
{
  "instances": [
    {
      "name": "MiInstanciaSQL",
      "server": "servidor\\instancia",
      "user": "usuario",
      "password": "contraseña"
    }
  ],
  "reportOptions": {
    "includePerfMetrics": true,
    "outputFormat": "html"
  }
}
🧩 Módulos / Funcionalidades Clave
dbatools-functions.ps1: funciones de nivel bajo que interactúan con dbatools

data-collector.ps1: orquesta consultas, recolecta métricas

html-generator.ps1: convierte datos en reporte visual con la plantilla

templates/: contiene la estructura base del HTML y estilo CSS

💡 Buenas prácticas / recomendaciones
Versiona settings.json cuidadosamente (o usa variables de entorno) si contiene credenciales

Puedes agendar la ejecución con un Task Scheduler o similar

Si amplías con nuevos módulos, sigue la misma estructura modular para mantener orden

🏷 Versiones / Releases
Puedes usar el sistema de tags de GitHub para marcar versiones importantes (ej: v1.0-final)

Crear una release desde GitHub con ZIP descargable, changelog, etc.

✍️ Autor
Santiago Restrepo
santiago.guevararestrepo@gmail.com