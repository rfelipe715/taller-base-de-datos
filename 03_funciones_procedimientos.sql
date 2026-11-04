-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 03_funciones_procedimientos.sql
--
-- FUNCIONES (siempre devuelven un valor con RETURN; no modifican datos,
-- por eso se pueden usar dentro de SELECT, UPDATE o INSERT)
--   Sin parametros : fn_productos_criticos, fn_venta_neta_total
--   Con parametros : fn_margen_pct, fn_descuento_cliente, fn_neto_venta,
--                    fn_total_venta, fn_venta_neta_periodo
--
-- PROCEDIMIENTOS (ejecutan acciones y modifican datos; no devuelven RETURN)
--   Sin parametros : sp_generar_alertas_stock, sp_recalcular_totales
--   Con parametros : sp_registrar_log, sp_ajustar_precios
--
-- Se crean antes que los packages (04), porque los packages los invocan.
-- ============================================================================
SET DEFINE OFF

-- ############################################################################
-- FUNCIONES CON PARAMETROS
-- ############################################################################

-- ----------------------------------------------------------------------------
-- Margen porcentual de un producto. Uso tipico: dentro de un SELECT sobre
-- toda la tabla PRODUCTO (procesamiento masivo).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_margen_pct (p_id_producto IN NUMBER)
RETURN NUMBER IS
    v_precio producto.precio_venta%TYPE;
    v_costo  producto.costo_unitario%TYPE;
BEGIN
    SELECT precio_venta, costo_unitario
      INTO v_precio, v_costo
      FROM producto
     WHERE id_producto = p_id_producto;

    IF NVL(v_precio, 0) = 0 THEN
        RETURN NULL;               -- sin precio no hay margen que calcular
    END IF;

    RETURN ROUND((v_precio - v_costo) / v_precio * 100, 2);
EXCEPTION
    WHEN NO_DATA_FOUND THEN        -- producto inexistente: caso limite controlado
        RETURN NULL;
END fn_margen_pct;
/

-- ----------------------------------------------------------------------------
-- Descuento que corresponde a cada tipo de cliente. Un tipo NULL o
-- desconocido devuelve 0 (caso limite controlado).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descuento_cliente (p_tipo_cliente IN VARCHAR2)
RETURN NUMBER IS
    v_descuento NUMBER;
BEGIN
    IF p_tipo_cliente = 'PREFERENTE' THEN
        v_descuento := 5;
    ELSIF p_tipo_cliente = 'EMPRESA' THEN
        v_descuento := 12;
    ELSE
        v_descuento := 0;
    END IF;

    RETURN v_descuento;
END fn_descuento_cliente;
/

-- ----------------------------------------------------------------------------
-- Venta neta de una venta (despues del descuento, antes del IVA).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_neto_venta (p_id_venta IN NUMBER)
RETURN NUMBER IS
    v_neto NUMBER;
BEGIN
    SELECT NVL(SUM(cantidad * precio_unitario * (1 - descuento_pct / 100)), 0)
      INTO v_neto
      FROM detalle_venta
     WHERE id_venta = p_id_venta;

    RETURN v_neto;
END fn_neto_venta;
/

-- ----------------------------------------------------------------------------
-- Total de una venta con IVA. Reutiliza fn_neto_venta: una funcion que
-- llama a otra funcion.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_venta (p_id_venta IN NUMBER)
RETURN NUMBER IS
BEGIN
    RETURN ROUND(fn_neto_venta(p_id_venta) * 1.19);
END fn_total_venta;
/

-- ----------------------------------------------------------------------------
-- Venta neta de un periodo, de todas las categorias o de una sola.
-- p_desde es inclusivo y p_hasta exclusivo: [p_desde, p_hasta).
-- Si p_id_categoria es NULL, suma todas las categorias.
-- Un rango invalido (desde posterior a hasta) devuelve NULL.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_venta_neta_periodo (
    p_desde        IN DATE,
    p_hasta        IN DATE,
    p_id_categoria IN NUMBER DEFAULT NULL
) RETURN NUMBER IS
    v_total NUMBER;
BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL OR p_desde > p_hasta THEN
        RETURN NULL;
    END IF;

    SELECT NVL(SUM(d.cantidad * d.precio_unitario * (1 - d.descuento_pct / 100)), 0)
      INTO v_total
      FROM detalle_venta d
      JOIN venta    v ON v.id_venta    = d.id_venta
      JOIN producto p ON p.id_producto = d.id_producto
     WHERE v.estado = 'EMITIDA'
       AND v.fecha_venta >= p_desde
       AND v.fecha_venta <  p_hasta
       AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria);

    RETURN v_total;
END fn_venta_neta_periodo;
/

-- ############################################################################
-- FUNCIONES SIN PARAMETROS
-- ############################################################################

-- ----------------------------------------------------------------------------
-- Cantidad de productos activos en o bajo su stock critico.
-- Recorre toda la tabla PRODUCTO en cada llamada.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_productos_criticos
RETURN NUMBER IS
    v_cantidad NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_cantidad
      FROM producto
     WHERE activo = 'S'
       AND stock_actual <= stock_critico;

    RETURN v_cantidad;
END fn_productos_criticos;
/

-- ----------------------------------------------------------------------------
-- Venta neta historica de todas las ventas emitidas.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_venta_neta_total
RETURN NUMBER IS
    v_total NUMBER;
BEGIN
    SELECT NVL(SUM(d.cantidad * d.precio_unitario * (1 - d.descuento_pct / 100)), 0)
      INTO v_total
      FROM detalle_venta d
      JOIN venta v ON v.id_venta = d.id_venta
     WHERE v.estado = 'EMITIDA';

    RETURN v_total;
END fn_venta_neta_total;
/

-- ############################################################################
-- PROCEDIMIENTOS CON PARAMETROS
-- ############################################################################

-- ----------------------------------------------------------------------------
-- Registra un error en la bitacora.
-- IMPORTANTE (correccion EP2): quien lo llama debe hacer ROLLBACK ANTES y
-- COMMIT DESPUES. Si se hace al reves, el ROLLBACK borra tambien el registro
-- del error (era lo que ocurria en la version de la EP1).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_log (
    p_origen  IN VARCHAR2,
    p_codigo  IN NUMBER,
    p_mensaje IN VARCHAR2
) IS
BEGIN
    INSERT INTO log_error (id_log, origen, codigo_error, mensaje)
    VALUES (seq_log.NEXTVAL, p_origen, p_codigo, SUBSTR(p_mensaje, 1, 500));
END sp_registrar_log;
/

-- ----------------------------------------------------------------------------
-- Ajusta en un porcentaje el precio de TODOS los productos activos de una
-- categoria (procesamiento masivo con parametros).
--   * Valida que la categoria exista y que el porcentaje sea razonable.
--   * Cada fila modificada dispara trg_audita_precio (trigger de FILA).
--   * La sentencia completa dispara trg_bitacora_producto (trigger de
--     SENTENCIA) una sola vez.
--   * Si algun precio queda bajo el costo, el trigger rechaza la sentencia
--     y se deshace todo: ningun producto queda a medio actualizar.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_ajustar_precios (
    p_id_categoria IN NUMBER,
    p_porcentaje   IN NUMBER
) IS
    v_existe NUMBER;
    v_filas  NUMBER;

    e_categoria_inexistente EXCEPTION;
    e_porcentaje_invalido   EXCEPTION;
BEGIN
    SELECT COUNT(*) INTO v_existe
      FROM categoria
     WHERE id_categoria = p_id_categoria;

    IF v_existe = 0 THEN
        RAISE e_categoria_inexistente;
    END IF;

    IF p_porcentaje IS NULL OR p_porcentaje < -50 OR p_porcentaje > 100 THEN
        RAISE e_porcentaje_invalido;
    END IF;

    UPDATE producto
       SET precio_venta = ROUND(precio_venta * (1 + p_porcentaje / 100))
     WHERE id_categoria = p_id_categoria
       AND activo = 'S';

    v_filas := SQL%ROWCOUNT;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Precios ajustados en ' || p_porcentaje ||
                         '% para ' || v_filas || ' productos.');
EXCEPTION
    WHEN e_categoria_inexistente THEN
        RAISE_APPLICATION_ERROR(-20020,
            'La categoria ' || p_id_categoria || ' no existe.');
    WHEN e_porcentaje_invalido THEN
        RAISE_APPLICATION_ERROR(-20021,
            'Porcentaje invalido: debe estar entre -50 y 100.');
    WHEN OTHERS THEN
        ROLLBACK;                              -- 1. deshace el ajuste
        sp_registrar_log('sp_ajustar_precios', SQLCODE, SQLERRM);
        COMMIT;                                -- 2. guarda solo el log
        RAISE;                                 -- 3. avisa a quien llamo
END sp_ajustar_precios;
/

-- ############################################################################
-- PROCEDIMIENTOS SIN PARAMETROS
-- ############################################################################

-- ----------------------------------------------------------------------------
-- Genera una alerta por cada producto en o bajo su stock critico.
-- Se puede ejecutar varias veces: no duplica alertas PENDIENTES.
-- Usa la funcion fn_productos_criticos (procedimiento -> funcion).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_generar_alertas_stock IS
    CURSOR c_criticos IS
        SELECT p.id_producto, p.sku, p.stock_actual, p.stock_critico
          FROM producto p
         WHERE p.activo = 'S'
           AND p.stock_actual <= p.stock_critico
           AND NOT EXISTS (SELECT 1
                             FROM alerta_stock a
                            WHERE a.id_producto = p.id_producto
                              AND a.estado = 'PENDIENTE');

    v_generadas NUMBER := 0;
BEGIN
    FOR r_prod IN c_criticos LOOP
        INSERT INTO alerta_stock (id_alerta, id_producto,
                                  stock_actual, stock_critico)
        VALUES (seq_alerta.NEXTVAL, r_prod.id_producto,
                r_prod.stock_actual, r_prod.stock_critico);

        v_generadas := v_generadas + 1;
        DBMS_OUTPUT.PUT_LINE('Alerta: ' || r_prod.sku ||
                             ' con stock ' || r_prod.stock_actual);
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Alertas nuevas: ' || v_generadas ||
                         ' | productos criticos: ' || fn_productos_criticos);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        sp_registrar_log('sp_generar_alertas_stock', SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END sp_generar_alertas_stock;
/

-- ----------------------------------------------------------------------------
-- Recalcula los totales de TODAS las ventas emitidas a partir de su detalle.
-- Una sola sentencia UPDATE masiva que usa funciones dentro de SQL.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_recalcular_totales IS
    v_filas NUMBER;
BEGIN
    UPDATE venta v
       SET v.total_neto  = ROUND(fn_neto_venta(v.id_venta)),
           v.total_iva   = ROUND(fn_neto_venta(v.id_venta) * 0.19),
           v.total_bruto = fn_total_venta(v.id_venta)
     WHERE v.estado = 'EMITIDA';

    v_filas := SQL%ROWCOUNT;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Totales recalculados en ' || v_filas || ' ventas.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        sp_registrar_log('sp_recalcular_totales', SQLCODE, SQLERRM);
        COMMIT;
        RAISE;
END sp_recalcular_totales;
/

PROMPT Funciones y procedimientos creados.
SHOW ERRORS
