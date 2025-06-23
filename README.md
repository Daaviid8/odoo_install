# odoo_install
Installing Local Odoo anywhere
1. exec odoo_analyzer (genera json con los datos de la maquina)
2. exec odoo_installer (coge el json con los datos del sistema e instala odoo y algunas dependencias importantes)
3. exec tools.sh (revisa la instalación de las dependencias importantes y luego crea un usuario de sistema enjaulado. Crea un entorno virtual e instala todo lo que falta ahi)
4. exec odoo.sh (comprueba todos los paquetes instalados y genera el daemon y lo pone a ejecutarse)
