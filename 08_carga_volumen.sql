-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 08_carga_volumen.sql   (OPCIONAL, ejecutar al final)
--
-- Demuestra el procesamiento MASIVO: genera 1.240 ventas del anio 2025
-- (31 productos x 40 ventas) usando los mismos objetos del proyecto:
--   * fn_descuento_cliente dentro de un INSERT ... SELECT   (funcion en SQL)
--   * trg_valida_detalle / trg_descuenta_stock por cada linea (triggers de fila)
--   * sp_recalcular_totales sobre todas las ventas          (procedimiento sin parametros)
--   * pkg_reportes.sp_generar_reporte para los 4 trimestres  (package)
--
-- Todo queda en 2025, asi que NO cambia los resultados de 2026 del informe.
-- Ejecutarlo despues de 07_pruebas.sql. Puede tardar unos segundos.
-- ============================================================================
SET SERVEROUTPUT ON
SET LINESIZE 200

DECLARE
    CURSOR c_productos IS
        SELECT id_producto, precio_venta
          FROM producto
         WHERE activo = 'S'
         ORDER BY id_producto;

    v_id_venta   NUMBER;
    v_id_cliente NUMBER;
    v_ventas     NUMBER := 0;
BEGIN
    -- 1. Reposicion de stock para que el trigger no rechace las lineas.
    --    Solo cambia el stock: no dispara los triggers de precio.
    UPDATE producto
       SET stock_actual = stock_actual + 500
     WHERE activo = 'S';

    INSERT INTO movimiento_stock (id_movimiento, id_producto, tipo_movimiento,
                                  cantidad, fecha, id_venta)
    SELECT seq_movimiento.NEXTVAL, id_producto, 'ENTRADA', 500,
           TO_DATE('01/01/2025','DD/MM/YYYY'), NULL
      FROM producto
     WHERE activo = 'S';

    -- 2. 40 ventas por producto, repartidas en el anio 2025
    FOR r_prod IN c_productos LOOP
        FOR i IN 1 .. 40 LOOP
            v_id_venta   := seq_venta.NEXTVAL;
            v_id_cliente := MOD(i, 12) + 1;

            INSERT INTO venta (id_venta, id_cliente, id_sucursal,
                               fecha_venta, estado)
            VALUES (v_id_venta, v_id_cliente, MOD(i, 4) + 1,
                    TO_DATE('01/01/2025','DD/MM/YYYY')
                        + MOD(i * 9 + r_prod.id_producto, 365),
                    'EMITIDA');

            -- La funcion almacenada calcula el descuento dentro del INSERT
            INSERT INTO detalle_venta (id_venta, nro_linea, id_producto,
                        cantidad, precio_unitario, descuento_pct)
            SELECT v_id_venta, 1, r_prod.id_producto, MOD(i, 3) + 1,
                   r_prod.precio_venta, fn_descuento_cliente(c.tipo_cliente)
              FROM cliente c
             WHERE c.id_cliente = v_id_cliente;

            v_ventas := v_ventas + 1;
        END LOOP;
    END LOOP;

    -- 3. Metas 2025 para todas las categorias activas
    INSERT INTO meta_categoria (id_categoria, anio, meta_q1, meta_q2, meta_q3, meta_q4)
    SELECT id_categoria, 2025, 1500000, 1500000, 1500000, 1500000
      FROM categoria
     WHERE activo = 'S';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Ventas generadas: ' || v_ventas);
END;
/

-- 4. Procesamiento masivo con los objetos del proyecto
BEGIN
    sp_recalcular_totales;
    FOR t IN 1 .. 4 LOOP
        pkg_reportes.sp_generar_reporte(2025, t);
    END LOOP;
END;
/

-- 5. Consulta de control: la suma de los 4 reportes debe ser igual a la
--    venta neta de 2025 que calcula la funcion.  [CAPTURA]
--    Cada valor se calcula en su propia subconsulta: si se mezcla SUM() con
--    columnas sin agrupar en el mismo SELECT, Oracle da ORA-00937.
SELECT (SELECT ROUND(SUM(venta_neta))
          FROM reporte_categoria
         WHERE anio = 2025)                                     AS suma_reportes_2025,
       ROUND(fn_venta_neta_periodo(TO_DATE('01/01/2025','DD/MM/YYYY'),
                                   TO_DATE('01/01/2026','DD/MM/YYYY'))) AS segun_funcion,
       (SELECT COUNT(*) FROM venta
         WHERE fecha_venta >= TO_DATE('01/01/2025','DD/MM/YYYY')
           AND fecha_venta <  TO_DATE('01/01/2026','DD/MM/YYYY')) AS ventas_2025
  FROM dual;

-- 6. Resumen por trimestre generado desde la tabla de resultados
SELECT trimestre,
       SUM(unidades)          AS unidades,
       ROUND(SUM(venta_neta)) AS venta_neta
  FROM reporte_categoria
 WHERE anio = 2025
 GROUP BY trimestre
 ORDER BY trimestre;
