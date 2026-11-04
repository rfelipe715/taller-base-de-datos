-- ============================================================================
-- TecnoParts SpA  |  BDY1103  |  Evaluacion Parcial 2
-- 05_triggers.sql
--
-- Un trigger se ejecuta solo cuando ocurre el evento indicado sobre la tabla.
--
--   NIVEL DE FILA      (FOR EACH ROW): se ejecuta una vez POR CADA FILA
--                      afectada y puede leer :OLD y :NEW.
--   NIVEL DE SENTENCIA (sin FOR EACH ROW): se ejecuta UNA SOLA VEZ por
--                      sentencia, aunque esta afecte muchas filas.
--
--   Fila      : trg_valida_detalle, trg_descuenta_stock, trg_audita_precio
--   Sentencia : trg_bloquea_borrado_venta, trg_bitacora_producto
--
-- Se crean DESPUES de cargar los datos (script 02), para que la carga
-- historica no dispare el descuento automatico de stock.
-- ============================================================================
SET DEFINE OFF

-- ############################################################################
-- TRIGGERS DE NIVEL DE FILA
-- ############################################################################

-- ----------------------------------------------------------------------------
-- Antes de insertar cada linea de venta:
--   1. Rechaza la linea si no hay stock suficiente.
--   2. Completa el costo historico (:NEW.costo_unitario) con el costo actual.
-- Una restriccion CHECK no puede hacer esto, porque el stock y el costo
-- estan en otra tabla.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_valida_detalle
BEFORE INSERT ON detalle_venta
FOR EACH ROW
DECLARE
    v_stock producto.stock_actual%TYPE;
    v_costo producto.costo_unitario%TYPE;
BEGIN
    SELECT stock_actual, costo_unitario
      INTO v_stock, v_costo
      FROM producto
     WHERE id_producto = :NEW.id_producto;

    IF v_stock < :NEW.cantidad THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Stock insuficiente del producto ' || :NEW.id_producto ||
            '. Disponible: ' || v_stock);
    END IF;

    :NEW.costo_unitario := v_costo;
END trg_valida_detalle;
/

-- ----------------------------------------------------------------------------
-- Despues de insertar cada linea: descuenta el stock y registra el
-- movimiento de salida.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_descuenta_stock
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE producto
       SET stock_actual = stock_actual - :NEW.cantidad
     WHERE id_producto = :NEW.id_producto;

    INSERT INTO movimiento_stock (id_movimiento, id_producto,
                                  tipo_movimiento, cantidad, id_venta)
    VALUES (seq_movimiento.NEXTVAL, :NEW.id_producto,
            'SALIDA', :NEW.cantidad, :NEW.id_venta);
END trg_descuenta_stock;
/

-- ----------------------------------------------------------------------------
-- Antes de cambiar el precio de cada producto: bloquea precios bajo el
-- costo y guarda el valor anterior (:OLD) y el nuevo (:NEW).
-- "UPDATE OF precio_venta": no se dispara cuando solo cambia el stock.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_audita_precio
BEFORE UPDATE OF precio_venta ON producto
FOR EACH ROW
BEGIN
    IF :NEW.precio_venta < :NEW.costo_unitario THEN
        RAISE_APPLICATION_ERROR(-20011,
            'El precio de ' || :OLD.sku || ' no puede quedar bajo su costo.');
    END IF;

    IF :NEW.precio_venta <> :OLD.precio_venta THEN
        INSERT INTO auditoria_precio (id_auditoria, id_producto,
                    precio_anterior, precio_nuevo, usuario_bd)
        VALUES (seq_auditoria.NEXTVAL, :OLD.id_producto,
                :OLD.precio_venta, :NEW.precio_venta, USER);
    END IF;
END trg_audita_precio;
/

-- ############################################################################
-- TRIGGERS DE NIVEL DE SENTENCIA
-- ############################################################################

-- ----------------------------------------------------------------------------
-- CONTROLA una accion: las ventas no se borran, se anulan.
-- Se dispara una vez antes de cualquier DELETE sobre VENTA, sin importar
-- cuantas filas afecte, y lo rechaza completo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bloquea_borrado_venta
BEFORE DELETE ON venta
BEGIN
    RAISE_APPLICATION_ERROR(-20012,
        'Las ventas no se eliminan. Use pkg_ventas.sp_anular_venta.');
END trg_bloquea_borrado_venta;
/

-- ----------------------------------------------------------------------------
-- REGISTRA una accion: deja UNA fila en la bitacora por cada sentencia que
-- inserta, borra o cambia precios en PRODUCTO.
-- Ejemplo: sp_ajustar_precios sobre una categoria de 5 productos genera
-- 5 filas en AUDITORIA_PRECIO (trigger de fila) y 1 fila aqui.
-- INSERTING, UPDATING y DELETING indican que operacion lo disparo.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_bitacora_producto
AFTER INSERT OR DELETE OR UPDATE OF precio_venta ON producto
DECLARE
    v_operacion bitacora_operacion.operacion%TYPE;
BEGIN
    IF INSERTING THEN
        v_operacion := 'INSERT';
    ELSIF DELETING THEN
        v_operacion := 'DELETE';
    ELSE
        v_operacion := 'UPDATE PRECIO';
    END IF;

    INSERT INTO bitacora_operacion (id_bitacora, tabla, operacion, usuario_bd)
    VALUES (seq_bitacora.NEXTVAL, 'PRODUCTO', v_operacion, USER);
END trg_bitacora_producto;
/

PROMPT Triggers creados.

SELECT trigger_name,
       trigger_type,          -- BEFORE EACH ROW / BEFORE STATEMENT / ...
       triggering_event,
       table_name,
       status
  FROM user_triggers
 ORDER BY table_name, trigger_name;
