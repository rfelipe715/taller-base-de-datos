-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 04_packages.sql
--
-- Un package tiene dos partes:
--   ESPECIFICACION (PACKAGE)      = lo PUBLICO: se puede usar desde fuera
--                                   como paquete.elemento
--   CUERPO         (PACKAGE BODY) = la implementacion, mas los elementos
--                                   PRIVADOS: los que solo existen en el
--                                   cuerpo y solo el propio package usa
--
-- pkg_ventas   : proceso transaccional de una venta
-- pkg_reportes : generacion de informacion (reporte por categoria)
-- ============================================================================
SET DEFINE OFF

-- ############################################################################
-- PKG_VENTAS - ESPECIFICACION (publico)
-- ############################################################################
CREATE OR REPLACE PACKAGE pkg_ventas AS

    -- Constante publica: el IVA del proceso de venta se define una sola vez
    c_iva CONSTANT NUMBER := 0.19;

    -- Excepciones publicas: quien llama puede capturarlas por su nombre
    e_stock_insuficiente  EXCEPTION;
    e_venta_sin_detalle   EXCEPTION;
    e_cliente_inexistente EXCEPTION;

    PROCEDURE sp_registrar_venta (p_id_cliente  IN  NUMBER,
                                  p_id_sucursal IN  NUMBER,
                                  p_id_venta    OUT NUMBER);

    PROCEDURE sp_agregar_linea   (p_id_venta    IN NUMBER,
                                  p_id_producto IN NUMBER,
                                  p_cantidad    IN NUMBER);

    PROCEDURE sp_cerrar_venta    (p_id_venta IN NUMBER);

    -- NUEVO EP2: alternativa controlada a borrar una venta
    PROCEDURE sp_anular_venta    (p_id_venta IN NUMBER);

END pkg_ventas;
/

-- ############################################################################
-- PKG_VENTAS - CUERPO
-- ############################################################################
CREATE OR REPLACE PACKAGE BODY pkg_ventas AS

    -- ================== ELEMENTOS PRIVADOS ==================
    -- No estan en la especificacion: desde fuera del package no existen.

    -- Excepcion privada: solo la usa el propio package
    e_venta_no_editable EXCEPTION;

    -- Funcion privada: siguiente numero de linea de una venta
    FUNCTION fn_siguiente_linea (p_id_venta IN NUMBER) RETURN NUMBER IS
        v_linea NUMBER;
    BEGIN
        SELECT NVL(MAX(nro_linea), 0) + 1
          INTO v_linea
          FROM detalle_venta
         WHERE id_venta = p_id_venta;
        RETURN v_linea;
    END fn_siguiente_linea;

    -- Procedimiento privado: solo una venta en BORRADOR acepta lineas
    PROCEDURE sp_validar_borrador (p_id_venta IN NUMBER) IS
        v_estado venta.estado%TYPE;
    BEGIN
        SELECT estado INTO v_estado
          FROM venta
         WHERE id_venta = p_id_venta;

        IF v_estado <> 'BORRADOR' THEN
            RAISE e_venta_no_editable;
        END IF;
    END sp_validar_borrador;

    -- ================== ELEMENTOS PUBLICOS ==================

    PROCEDURE sp_registrar_venta (p_id_cliente  IN  NUMBER,
                                  p_id_sucursal IN  NUMBER,
                                  p_id_venta    OUT NUMBER) IS
        v_existe NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_existe
          FROM cliente
         WHERE id_cliente = p_id_cliente;

        IF v_existe = 0 THEN
            RAISE e_cliente_inexistente;
        END IF;

        p_id_venta := seq_venta.NEXTVAL;

        INSERT INTO venta (id_venta, id_cliente, id_sucursal, estado)
        VALUES (p_id_venta, p_id_cliente, p_id_sucursal, 'BORRADOR');
    EXCEPTION
        WHEN e_cliente_inexistente THEN
            ROLLBACK;
            sp_registrar_log('pkg_ventas.sp_registrar_venta', -20001,
                'Cliente inexistente: ' || p_id_cliente);
            COMMIT;
            RAISE_APPLICATION_ERROR(-20001,
                'El cliente ' || p_id_cliente || ' no existe.');
    END sp_registrar_venta;

    -- ------------------------------------------------------------------
    PROCEDURE sp_agregar_linea (p_id_venta    IN NUMBER,
                                p_id_producto IN NUMBER,
                                p_cantidad    IN NUMBER) IS
        v_stock     producto.stock_actual%TYPE;
        v_precio    producto.precio_venta%TYPE;
        v_tipo      cliente.tipo_cliente%TYPE;
        v_linea     NUMBER;
        v_descuento NUMBER;
    BEGIN
        sp_validar_borrador(p_id_venta);                 -- privado

        SELECT stock_actual, precio_venta
          INTO v_stock, v_precio
          FROM producto
         WHERE id_producto = p_id_producto;

        IF v_stock < p_cantidad THEN
            RAISE e_stock_insuficiente;
        END IF;

        SELECT c.tipo_cliente
          INTO v_tipo
          FROM venta v
          JOIN cliente c ON c.id_cliente = v.id_cliente
         WHERE v.id_venta = p_id_venta;

        -- Una funcion PRIVADA no se puede usar dentro de una sentencia SQL
        -- (ni siquiera desde el cuerpo): por eso se asigna antes a variables.
        v_linea     := fn_siguiente_linea(p_id_venta);   -- funcion privada
        v_descuento := fn_descuento_cliente(v_tipo);     -- funcion almacenada

        -- costo_unitario lo completa el trigger trg_valida_detalle
        INSERT INTO detalle_venta (id_venta, nro_linea, id_producto,
                                   cantidad, precio_unitario, descuento_pct)
        VALUES (p_id_venta, v_linea, p_id_producto,
                p_cantidad, v_precio, v_descuento);
    EXCEPTION
        WHEN e_stock_insuficiente THEN
            ROLLBACK;
            sp_registrar_log('pkg_ventas.sp_agregar_linea', -20002,
                'Stock insuficiente del producto ' || p_id_producto);
            COMMIT;
            RAISE_APPLICATION_ERROR(-20002,
                'Stock insuficiente. Disponible: ' || v_stock ||
                ', solicitado: ' || p_cantidad);
        WHEN e_venta_no_editable THEN
            RAISE_APPLICATION_ERROR(-20005,
                'La venta ' || p_id_venta || ' ya no esta en BORRADOR.');
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'La venta o el producto indicado no existe.');
    END sp_agregar_linea;

    -- ------------------------------------------------------------------
    PROCEDURE sp_cerrar_venta (p_id_venta IN NUMBER) IS
        v_lineas NUMBER;
        v_neto   NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_lineas
          FROM detalle_venta
         WHERE id_venta = p_id_venta;

        IF v_lineas = 0 THEN
            RAISE e_venta_sin_detalle;
        END IF;

        v_neto := fn_neto_venta(p_id_venta);              -- funcion almacenada

        UPDATE venta
           SET total_neto  = ROUND(v_neto),
               total_iva   = ROUND(v_neto * c_iva),
               total_bruto = ROUND(v_neto * (1 + c_iva)),
               estado      = 'EMITIDA'
         WHERE id_venta = p_id_venta;

        COMMIT;
    EXCEPTION
        WHEN e_venta_sin_detalle THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20004,
                'No se puede emitir una venta sin lineas de detalle.');
        WHEN OTHERS THEN
            ROLLBACK;
            sp_registrar_log('pkg_ventas.sp_cerrar_venta', SQLCODE, SQLERRM);
            COMMIT;
            RAISE;
    END sp_cerrar_venta;

    -- ------------------------------------------------------------------
    -- Anula una venta emitida y devuelve su stock, linea por linea.
    PROCEDURE sp_anular_venta (p_id_venta IN NUMBER) IS
        CURSOR c_lineas (p_venta NUMBER) IS
            SELECT id_producto, cantidad
              FROM detalle_venta
             WHERE id_venta = p_venta;

        v_estado venta.estado%TYPE;
    BEGIN
        SELECT estado INTO v_estado
          FROM venta
         WHERE id_venta = p_id_venta;

        IF v_estado <> 'EMITIDA' THEN
            RAISE e_venta_no_editable;                    -- privada
        END IF;

        FOR r_linea IN c_lineas(p_id_venta) LOOP
            UPDATE producto
               SET stock_actual = stock_actual + r_linea.cantidad
             WHERE id_producto = r_linea.id_producto;

            INSERT INTO movimiento_stock (id_movimiento, id_producto,
                        tipo_movimiento, cantidad, id_venta)
            VALUES (seq_movimiento.NEXTVAL, r_linea.id_producto,
                    'ENTRADA', r_linea.cantidad, p_id_venta);
        END LOOP;

        UPDATE venta SET estado = 'ANULADA' WHERE id_venta = p_id_venta;
        COMMIT;
    EXCEPTION
        WHEN e_venta_no_editable THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Solo se puede anular una venta EMITIDA.');
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'La venta ' || p_id_venta || ' no existe.');
        WHEN OTHERS THEN
            ROLLBACK;
            sp_registrar_log('pkg_ventas.sp_anular_venta', SQLCODE, SQLERRM);
            COMMIT;
            RAISE;
    END sp_anular_venta;

END pkg_ventas;
/

-- ############################################################################
-- PKG_REPORTES - ESPECIFICACION (publico)
-- Reemplaza al bloque anonimo de la EP1: el mismo reporte, ahora como
-- procedimiento con parametros, guardado en la tabla REPORTE_CATEGORIA.
-- ############################################################################
CREATE OR REPLACE PACKAGE pkg_reportes AS

    e_trimestre_invalido EXCEPTION;

    -- Procesa todas las categorias del trimestre y guarda el resultado
    PROCEDURE sp_generar_reporte (p_anio IN NUMBER, p_trimestre IN NUMBER);

    -- Muestra por pantalla un reporte ya generado
    PROCEDURE sp_mostrar_reporte (p_anio IN NUMBER, p_trimestre IN NUMBER);

    -- Cumplimiento guardado de una categoria; se puede usar en un SELECT
    FUNCTION fn_cumplimiento (p_id_categoria IN NUMBER,
                              p_anio         IN NUMBER,
                              p_trimestre    IN NUMBER) RETURN NUMBER;

END pkg_reportes;
/

-- ############################################################################
-- PKG_REPORTES - CUERPO
-- ############################################################################
CREATE OR REPLACE PACKAGE BODY pkg_reportes AS

    -- ================== ELEMENTOS PRIVADOS ==================

    -- Tipos privados (RECORD y VARRAY de la EP1)
    TYPE t_resumen IS RECORD (
        unidades    NUMBER,
        venta_neta  NUMBER,
        costo_total NUMBER,
        margen      NUMBER,
        meta        NUMBER,
        cumplimiento NUMBER
    );

    TYPE t_metas IS VARRAY(4) OF NUMBER;

    -- Variables privadas del package: contadores de la ultima ejecucion
    v_con_meta NUMBER := 0;
    v_sin_meta NUMBER := 0;

    -- Cursores privados
    CURSOR c_categorias IS
        SELECT id_categoria, nombre
          FROM categoria
         WHERE activo = 'S'
         ORDER BY id_categoria;

    -- Correccion EP2: en la EP1 el LEFT JOIN a VENTA no filtraba las lineas
    -- y se sumaban ventas anuladas y de otros periodos. Ahora el filtro se
    -- aplica en una subconsulta antes de unir con PRODUCTO.
    CURSOR c_productos (p_id_categoria NUMBER, p_desde DATE, p_hasta DATE) IS
        SELECT p.id_producto,
               NVL(SUM(dv.cantidad), 0) AS unidades,
               NVL(SUM(dv.cantidad * dv.precio_unitario
                       * (1 - dv.descuento_pct / 100)), 0) AS venta_neta,
               NVL(SUM(dv.cantidad * dv.costo_unitario), 0) AS costo_total
          FROM producto p
          LEFT JOIN (SELECT d.id_producto, d.cantidad, d.precio_unitario,
                            d.descuento_pct, d.costo_unitario
                       FROM detalle_venta d
                       JOIN venta v ON v.id_venta = d.id_venta
                      WHERE v.estado = 'EMITIDA'
                        AND v.fecha_venta >= p_desde
                        AND v.fecha_venta <  p_hasta) dv
                 ON dv.id_producto = p.id_producto
         WHERE p.id_categoria = p_id_categoria
           AND p.activo = 'S'
         GROUP BY p.id_producto;

    -- Funcion privada: margen sin dividir por cero
    FUNCTION fn_calcular_margen (p_neta IN NUMBER, p_costo IN NUMBER)
    RETURN NUMBER IS
    BEGIN
        RETURN ROUND((p_neta - p_costo) / p_neta * 100, 2);
    EXCEPTION
        WHEN ZERO_DIVIDE THEN
            RETURN NULL;
    END fn_calcular_margen;

    -- Funcion privada: meta del trimestre usando el VARRAY de 4 metas
    FUNCTION fn_meta_trimestre (p_id_categoria IN NUMBER,
                                p_anio         IN NUMBER,
                                p_trimestre    IN NUMBER) RETURN NUMBER IS
        v_metas t_metas;
        v_q1 NUMBER; v_q2 NUMBER; v_q3 NUMBER; v_q4 NUMBER;
    BEGIN
        SELECT meta_q1, meta_q2, meta_q3, meta_q4
          INTO v_q1, v_q2, v_q3, v_q4
          FROM meta_categoria
         WHERE id_categoria = p_id_categoria
           AND anio = p_anio;

        v_metas := t_metas(v_q1, v_q2, v_q3, v_q4);
        RETURN v_metas(p_trimestre);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN       -- categoria sin metas cargadas
            RETURN NULL;
    END fn_meta_trimestre;

    -- Procedimiento privado: fechas del trimestre [desde, hasta)
    PROCEDURE sp_rango_trimestre (p_anio      IN  NUMBER,
                                  p_trimestre IN  NUMBER,
                                  p_desde     OUT DATE,
                                  p_hasta     OUT DATE) IS
    BEGIN
        IF p_trimestre IS NULL OR p_trimestre NOT BETWEEN 1 AND 4 THEN
            RAISE e_trimestre_invalido;
        END IF;

        p_desde := ADD_MONTHS(TO_DATE('01/01/' || p_anio, 'DD/MM/YYYY'),
                              (p_trimestre - 1) * 3);
        p_hasta := ADD_MONTHS(p_desde, 3);
    END sp_rango_trimestre;

    -- ================== ELEMENTOS PUBLICOS ==================

    PROCEDURE sp_generar_reporte (p_anio IN NUMBER, p_trimestre IN NUMBER) IS
        v_desde   DATE;
        v_hasta   DATE;
        v_resumen t_resumen;
    BEGIN
        sp_rango_trimestre(p_anio, p_trimestre, v_desde, v_hasta);

        -- Re-ejecutable: borra el resultado anterior del mismo periodo
        DELETE FROM reporte_categoria
         WHERE anio = p_anio AND trimestre = p_trimestre;

        v_con_meta := 0;
        v_sin_meta := 0;

        FOR r_cat IN c_categorias LOOP
            v_resumen.unidades    := 0;
            v_resumen.venta_neta  := 0;
            v_resumen.costo_total := 0;

            FOR r_prod IN c_productos(r_cat.id_categoria, v_desde, v_hasta) LOOP
                v_resumen.unidades    := v_resumen.unidades    + r_prod.unidades;
                v_resumen.venta_neta  := v_resumen.venta_neta  + r_prod.venta_neta;
                v_resumen.costo_total := v_resumen.costo_total + r_prod.costo_total;
            END LOOP;

            v_resumen.margen := fn_calcular_margen(v_resumen.venta_neta,
                                                   v_resumen.costo_total);
            v_resumen.meta   := fn_meta_trimestre(r_cat.id_categoria,
                                                  p_anio, p_trimestre);

            IF NVL(v_resumen.meta, 0) = 0 THEN
                v_resumen.cumplimiento := NULL;   -- sin meta o meta en cero
                v_sin_meta := v_sin_meta + 1;
            ELSE
                v_resumen.cumplimiento :=
                    ROUND(v_resumen.venta_neta / v_resumen.meta * 100, 2);
                v_con_meta := v_con_meta + 1;
            END IF;

            INSERT INTO reporte_categoria (anio, trimestre, id_categoria,
                        unidades, venta_neta, costo_total, margen_pct,
                        meta, cumplimiento_pct)
            VALUES (p_anio, p_trimestre, r_cat.id_categoria,
                    v_resumen.unidades, ROUND(v_resumen.venta_neta, 2),
                    v_resumen.costo_total, v_resumen.margen,
                    v_resumen.meta, v_resumen.cumplimiento);
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Reporte ' || p_anio || '-T' || p_trimestre ||
            ' generado: ' || v_con_meta || ' categorias con meta, ' ||
            v_sin_meta || ' sin meta valida.');
    EXCEPTION
        WHEN e_trimestre_invalido THEN
            RAISE_APPLICATION_ERROR(-20030,
                'Trimestre invalido: ' || p_trimestre || '. Debe ser 1, 2, 3 o 4.');
        WHEN OTHERS THEN
            ROLLBACK;
            sp_registrar_log('pkg_reportes.sp_generar_reporte', SQLCODE, SQLERRM);
            COMMIT;
            RAISE;
    END sp_generar_reporte;

    -- ------------------------------------------------------------------
    PROCEDURE sp_mostrar_reporte (p_anio IN NUMBER, p_trimestre IN NUMBER) IS
        CURSOR c_reporte IS
            SELECT c.nombre, r.unidades, r.venta_neta, r.margen_pct,
                   r.meta, r.cumplimiento_pct
              FROM reporte_categoria r
              JOIN categoria c ON c.id_categoria = r.id_categoria
             WHERE r.anio = p_anio
               AND r.trimestre = p_trimestre
             ORDER BY r.id_categoria;

        v_filas NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('TECNOPARTS - REPORTE ' || p_anio || ' T' || p_trimestre);
        DBMS_OUTPUT.PUT_LINE(RPAD('CATEGORIA', 20) || LPAD('UNID', 6) ||
            LPAD('VENTA NETA', 14) || LPAD('MARGEN', 9) || LPAD('CUMPL.', 14));

        FOR r IN c_reporte LOOP
            DBMS_OUTPUT.PUT_LINE(RPAD(r.nombre, 20) || LPAD(r.unidades, 6) ||
                LPAD(TO_CHAR(r.venta_neta, '999G999G999'), 14) ||
                LPAD(NVL(TO_CHAR(r.margen_pct), '-'), 9) ||
                LPAD(NVL(TO_CHAR(r.cumplimiento_pct), 'no calculable'), 14));
            v_filas := v_filas + 1;
        END LOOP;

        IF v_filas = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No hay reporte generado para ese periodo.');
        END IF;
    END sp_mostrar_reporte;

    -- ------------------------------------------------------------------
    FUNCTION fn_cumplimiento (p_id_categoria IN NUMBER,
                              p_anio         IN NUMBER,
                              p_trimestre    IN NUMBER) RETURN NUMBER IS
        v_cumplimiento reporte_categoria.cumplimiento_pct%TYPE;
    BEGIN
        SELECT cumplimiento_pct
          INTO v_cumplimiento
          FROM reporte_categoria
         WHERE id_categoria = p_id_categoria
           AND anio = p_anio
           AND trimestre = p_trimestre;

        RETURN v_cumplimiento;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN       -- reporte no generado para ese periodo
            RETURN NULL;
    END fn_cumplimiento;

END pkg_reportes;
/

PROMPT Packages pkg_ventas y pkg_reportes creados.
SHOW ERRORS
