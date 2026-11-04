-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 00_instalar.sql   Script maestro. Ejecutar desde la carpeta de los scripts.
--
-- El orden importa:
--   02 (datos) va antes de 05 (triggers): la carga historica no debe
--      disparar el descuento automatico de stock.
--   03 (funciones y procedimientos) va antes de 04 (packages): los
--      packages los invocan.
-- ============================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF
SET LINESIZE 200

PROMPT ### 1/5 Creando tablas ###
@@01_crear_tablas.sql

PROMPT ### 2/5 Cargando datos ###
@@02_poblar_datos.sql

PROMPT ### 3/5 Creando funciones y procedimientos ###
@@03_funciones_procedimientos.sql

PROMPT ### 4/5 Creando packages ###
@@04_packages.sql

PROMPT ### 5/5 Creando triggers ###
@@05_triggers.sql

PROMPT ### Verificacion: cantidad de objetos y objetos invalidos ###
SELECT object_type, COUNT(*) AS cantidad
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID';

PROMPT Instalacion terminada. Siguientes pasos:
PROMPT   06_ejecutar_reporte.sql   genera y muestra el reporte 2026-T3
PROMPT   07_pruebas.sql            17 pruebas de procedimientos, funciones, packages y triggers
PROMPT   08_carga_volumen.sql      (opcional) 1.240 ventas de 2025 para el procesamiento masivo
