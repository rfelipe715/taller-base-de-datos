-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 06_ejecutar_reporte.sql
--
-- En la EP1 el reporte era un bloque anonimo de 200 lineas que habia que
-- editar para cambiar el periodo. En la EP2 esa logica vive en
-- pkg_reportes.sp_generar_reporte(anio, trimestre): este script solo lo
-- invoca, igual que lo haria cualquier otra aplicacion o proceso.
-- ============================================================================
SET SERVEROUTPUT ON
SET LINESIZE 200

-- 1) Uso desde un programa PL/SQL (bloque anonimo)
BEGIN
    pkg_reportes.sp_generar_reporte(2026, 3);
    pkg_reportes.sp_mostrar_reporte(2026, 3);
END;
/

-- 2) Uso desde SQL: el resultado queda en una tabla y se consulta con SELECT,
--    combinando la funcion publica del package con funciones almacenadas.
SELECT c.nombre                                         AS categoria,
       r.unidades,
       r.venta_neta,
       r.margen_pct,
       pkg_reportes.fn_cumplimiento(r.id_categoria, 2026, 3) AS cumplimiento_pct,
       fn_venta_neta_periodo(TO_DATE('01/07/2026','DD/MM/YYYY'),
                             TO_DATE('01/10/2026','DD/MM/YYYY'),
                             r.id_categoria)            AS control_funcion
  FROM reporte_categoria r
  JOIN categoria c ON c.id_categoria = r.id_categoria
 WHERE r.anio = 2026 AND r.trimestre = 3
 ORDER BY r.id_categoria;

-- 3) Consulta de control del procesamiento masivo:
--    la suma del reporte debe ser igual a la que entrega la funcion.
SELECT (SELECT ROUND(SUM(venta_neta))
          FROM reporte_categoria
         WHERE anio = 2026 AND trimestre = 3)                   AS suma_reporte,
       ROUND(fn_venta_neta_periodo(TO_DATE('01/07/2026','DD/MM/YYYY'),
                                   TO_DATE('01/10/2026','DD/MM/YYYY'))) AS suma_funcion
  FROM dual;
