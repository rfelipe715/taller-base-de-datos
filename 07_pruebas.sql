-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 07_pruebas.sql
--
-- Sigue las "pruebas minimas recomendadas" de la guia de la EP2.
-- Cada prueba indica el RESULTADO ESPERADO y lleva la marca [CAPTURA] cuando
-- conviene sacar una captura de pantalla para el informe o la presentacion.
--
-- Ejecutar con F5 (Run Script) DESPUES de 00_instalar.sql y 06.
-- La prueba 10 FALLA A PROPOSITO (demuestra que un elemento privado no
-- existe fuera del package): SQL Developer muestra el error y continua.
-- ============================================================================
SET SERVEROUTPUT ON
SET LINESIZE 200

-- ============================================================================
-- PROCEDIMIENTOS
-- ============================================================================

PROMPT ===== P1. Procedimiento SIN parametros + control masivo [CAPTURA] =====
-- Esperado: 3 alertas (CPU-I7-13700K, GPU-RTX4070, MB-X670E) y el conteo
-- de alertas pendientes (3) coincide con la funcion fn_productos_criticos.
-- Si se ejecuta dos veces, la segunda genera 0: no duplica alertas.
BEGIN
    sp_generar_alertas_stock;
END;
/
SELECT (SELECT COUNT(*) FROM alerta_stock WHERE estado = 'PENDIENTE') AS alertas_pendientes,
       fn_productos_criticos                                          AS segun_funcion
  FROM dual;

PROMPT ===== P2. Procedimiento SIN parametros que usa funciones en SQL =====
-- Esperado: "Totales recalculados en 20 ventas.", 20 ventas emitidas y una
-- suma de 7.767.506 en las cabeceras contra 7.767.505 en el detalle: la
-- diferencia de $1 viene de redondear cada boleta por separado.
BEGIN
    sp_recalcular_totales;
END;
/
SELECT v.ventas_emitidas,
       v.suma_cabeceras,
       ROUND(fn_venta_neta_total)    AS suma_detalle
  FROM (SELECT COUNT(*)        AS ventas_emitidas,
               SUM(total_neto) AS suma_cabeceras
          FROM venta
         WHERE estado = 'EMITIDA') v;

PROMPT ===== P3. Procedimiento CON parametros, valores validos [CAPTURA] =====
-- Esperado: "Precios ajustados en 5% para 5 productos." (categoria 8)
EXECUTE sp_ajustar_precios(8, 5);

-- La misma llamada con CALL, que es una sentencia SQL
-- (se deja comentada para no subir los precios dos veces):
-- CALL sp_ajustar_precios(8, 5);

PROMPT ===== P4. Procedimiento CON parametros, valores invalidos [CAPTURA] =====
-- Esperado: tres errores controlados, con mensaje claro, y los precios de
-- la categoria 8 iguales a los que dejo la prueba P3.
BEGIN
    sp_ajustar_precios(99, 5);                 -- categoria inexistente
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/
BEGIN
    sp_ajustar_precios(8, 500);                -- porcentaje fuera de rango
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/
BEGIN
    sp_ajustar_precios(8, -50);                -- dejaria precios bajo costo
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/
SELECT sku, precio_venta, costo_unitario
  FROM producto
 WHERE id_categoria = 8
 ORDER BY id_producto;

-- ============================================================================
-- FUNCIONES
-- ============================================================================

PROMPT ===== P5. Funciones SIN parametros dentro de un SELECT [CAPTURA] =====
SELECT fn_productos_criticos        AS productos_criticos,
       ROUND(fn_venta_neta_total)   AS venta_neta_historica
  FROM dual;

PROMPT ===== P6. Funciones CON parametros desde SQL (masivo) [CAPTURA] =====
-- Una llamada por cada fila de la tabla
SELECT sku,
       precio_venta,
       fn_margen_pct(id_producto) AS margen_pct
  FROM producto
 WHERE activo = 'S'
 ORDER BY margen_pct DESC;

SELECT c.nombre,
       ROUND(fn_venta_neta_periodo(TO_DATE('01/07/2026','DD/MM/YYYY'),
                                   TO_DATE('01/10/2026','DD/MM/YYYY'),
                                   c.id_categoria)) AS venta_q3
  FROM categoria c
 WHERE c.activo = 'S'
 ORDER BY c.id_categoria;

PROMPT ===== P7. Funciones CON parametros desde PL/SQL y casos limite =====
-- Esperado: margen de un producto real, NULL para uno inexistente,
-- 0 para un tipo de cliente NULL y NULL para un rango de fechas invertido.
BEGIN
    DBMS_OUTPUT.PUT_LINE('Margen producto 101   : ' || fn_margen_pct(101));
    DBMS_OUTPUT.PUT_LINE('Margen producto 999999: ' ||
                         NVL(TO_CHAR(fn_margen_pct(999999)), 'NULL (no existe)'));
    DBMS_OUTPUT.PUT_LINE('Descuento tipo NULL   : ' || fn_descuento_cliente(NULL));
    DBMS_OUTPUT.PUT_LINE('Rango invertido       : ' ||
        NVL(TO_CHAR(fn_venta_neta_periodo(TO_DATE('01/10/2026','DD/MM/YYYY'),
                                          TO_DATE('01/07/2026','DD/MM/YYYY'))),
            'NULL (rango invalido)'));
END;
/

-- ============================================================================
-- USO CRUZADO DE OBJETOS
-- ============================================================================

PROMPT ===== P8. Flujo completo: package -> funciones -> triggers [CAPTURA] =====
-- Esperado: venta creada, total con IVA, stock del producto 101 baja en 2
-- (lo descuenta el trigger) y el costo historico queda guardado en la linea.
DECLARE
    v_id_venta  NUMBER;
    v_stock_ini NUMBER;
    v_stock_fin NUMBER;
BEGIN
    SELECT stock_actual INTO v_stock_ini FROM producto WHERE id_producto = 101;

    pkg_ventas.sp_registrar_venta(3, 1, v_id_venta);   -- cliente EMPRESA
    pkg_ventas.sp_agregar_linea(v_id_venta, 101, 2);
    pkg_ventas.sp_agregar_linea(v_id_venta, 401, 4);
    pkg_ventas.sp_cerrar_venta(v_id_venta);

    SELECT stock_actual INTO v_stock_fin FROM producto WHERE id_producto = 101;

    DBMS_OUTPUT.PUT_LINE('Venta creada        : ' || v_id_venta);
    DBMS_OUTPUT.PUT_LINE('Total con IVA       : ' || fn_total_venta(v_id_venta));
    DBMS_OUTPUT.PUT_LINE('Stock producto 101  : ' || v_stock_ini || ' -> ' || v_stock_fin);
END;
/
SELECT id_venta, nro_linea, id_producto, cantidad, descuento_pct, costo_unitario
  FROM detalle_venta
 WHERE id_venta = (SELECT MAX(id_venta) FROM venta);

-- ============================================================================
-- PACKAGES
-- ============================================================================

PROMPT ===== P9. Package: elementos PUBLICOS desde fuera [CAPTURA] =====
BEGIN
    pkg_reportes.sp_generar_reporte(2026, 3);
    DBMS_OUTPUT.PUT_LINE('IVA publico de pkg_ventas: ' || pkg_ventas.c_iva);
END;
/
SELECT pkg_reportes.fn_cumplimiento(1, 2026, 3) AS cumplimiento_procesadores
  FROM dual;

PROMPT ===== P10. Package: elemento PRIVADO desde fuera (DEBE FALLAR) [CAPTURA] =====
-- Esperado: error PLS-00302 "component 'FN_CALCULAR_MARGEN' must be declared".
-- La funcion existe en el cuerpo de pkg_reportes, pero no en su
-- especificacion: desde fuera del package no se puede usar.
BEGIN
    DBMS_OUTPUT.PUT_LINE(pkg_reportes.fn_calcular_margen(100, 60));
END;
/

PROMPT ===== P11. Parametro invalido en el package =====
-- Esperado: ORA-20030 Trimestre invalido: 5.
BEGIN
    pkg_reportes.sp_generar_reporte(2026, 5);
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/

-- ============================================================================
-- TRIGGERS
-- ============================================================================

PROMPT ===== P12. Trigger de FILA vs trigger de SENTENCIA [CAPTURA] =====
-- La prueba P3 cambio 5 precios con UNA sola sentencia UPDATE.
-- Esperado: 5 filas en AUDITORIA_PRECIO (una por fila, con :OLD y :NEW)
--           1 fila  en BITACORA_OPERACION (una por sentencia).
SELECT p.sku, a.precio_anterior, a.precio_nuevo, a.usuario_bd
  FROM auditoria_precio a
  JOIN producto p ON p.id_producto = a.id_producto
 ORDER BY a.id_auditoria;

SELECT id_bitacora, tabla, operacion, usuario_bd,
       TO_CHAR(fecha, 'DD/MM/YYYY HH24:MI:SS') AS fecha
  FROM bitacora_operacion
 ORDER BY id_bitacora;

PROMPT ===== P13. Trigger de SENTENCIA que controla una accion [CAPTURA] =====
-- Esperado: ORA-20012 Las ventas no se eliminan. Use pkg_ventas.sp_anular_venta.
BEGIN
    DELETE FROM venta WHERE estado = 'ANULADA';
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/

PROMPT ===== P14. La alternativa permitida: anular con el package =====
-- Esperado: la venta de la prueba P8 queda ANULADA y el stock vuelve.
DECLARE
    v_id_venta NUMBER;
    v_stock    NUMBER;
BEGIN
    SELECT MAX(id_venta) INTO v_id_venta FROM venta;
    pkg_ventas.sp_anular_venta(v_id_venta);
    SELECT stock_actual INTO v_stock FROM producto WHERE id_producto = 101;
    DBMS_OUTPUT.PUT_LINE('Venta ' || v_id_venta || ' anulada. Stock 101: ' || v_stock);
END;
/

PROMPT ===== P15. Trigger de FILA que rechaza una operacion =====
-- Esperado: ORA-20011, el precio no puede quedar bajo el costo.
BEGIN
    UPDATE producto SET precio_venta = 1000 WHERE id_producto = 101;
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK  -> ' || SQLERRM);
END;
/

-- ============================================================================
-- ESTADO FINAL
-- ============================================================================

PROMPT ===== P16. Bitacora de errores (corregida en la EP2) [CAPTURA] =====
-- Esperado: aparece el error de la prueba P4 (-50%). En la EP1 esta tabla
-- quedaba vacia porque el ROLLBACK del llamador borraba el registro.
SELECT id_log, origen, codigo_error, SUBSTR(mensaje, 1, 70) AS mensaje
  FROM log_error
 ORDER BY id_log;

PROMPT ===== P17. Objetos del proyecto: ninguno INVALID [CAPTURA] =====
SELECT object_type, object_name, status
  FROM user_objects
 WHERE object_type IN ('FUNCTION','PROCEDURE','PACKAGE','PACKAGE BODY','TRIGGER')
 ORDER BY object_type, object_name;
