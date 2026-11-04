# Cambios de la EP1 a la EP2 — TecnoParts SpA

La EP2 parte de la rama `referencia-tecnoparts` (EP1). El caso, los datos y la estructura se mantienen; se agregó lo que piden los requerimientos nuevos: **procedimientos y funciones con y sin parámetros**, **packages con elementos públicos y privados**, **triggers de fila y de sentencia**, y que todo trabaje como **una solución integral**.

## Resumen en números

| Objeto | EP1 | EP2 | Nuevos |
|---|---|---|---|
| Tablas | 12 | 18 | `reporte_categoria`, `bitacora_operacion` + 4 complementarias: `cargo`, `empleado`, `orden_compra`, `detalle_orden_compra` |
| Funciones | 3 | 7 | `fn_neto_venta`, `fn_venta_neta_periodo`, `fn_productos_criticos`, `fn_venta_neta_total` |
| Procedimientos | 2 | 4 | `sp_ajustar_precios`, `sp_recalcular_totales` |
| Packages | 1 | 2 | `pkg_reportes` (el bloque anónimo de la EP1 convertido en package) |
| Triggers | 3 (de fila) | 5 | `trg_bloquea_borrado_venta`, `trg_bitacora_producto` (de sentencia) |

## Scripts

| EP1 | EP2 | Qué cambió |
|---|---|---|
| `01_crear_tablas.sql` | igual nombre | 2 tablas nuevas + 4 complementarias, 3 columnas nuevas, 3 FK que faltaban, `seq_bitacora` y `seq_orden` |
| `02_poblar_datos.sql` | igual nombre | `detalle_venta` con lista de columnas; se completa `costo_unitario`; `stock_critico` ajustado en 3 productos para que existan alertas; 4 cargos, 10 empleados, vendedor por venta y 2 órdenes de compra |
| `03_funciones_procedimientos.sql` | igual nombre | 4 funciones y 2 procedimientos nuevos |
| `04_packages.sql` | igual nombre | `pkg_ventas` ampliado + `pkg_reportes` nuevo |
| `05_triggers.sql` | igual nombre | `trg_valida_detalle` fija el costo; 2 triggers de sentencia nuevos |
| `06_bloque_anonimo.sql` | **`06_ejecutar_reporte.sql`** | El bloque de 240 líneas ahora solo llama a `pkg_reportes` |
| `07_pruebas.sql` | igual nombre | Pruebas P1 a P17 ordenadas según la guía, con marcas `[CAPTURA]` |
| — | **`08_carga_volumen.sql`** | Opcional: 1.240 ventas de 2025 para demostrar procesamiento masivo |

## Modelo relacional

- `DETALLE_VENTA.costo_unitario`: el costo **al momento de la venta**. Lo llena `trg_valida_detalle` con `:NEW`. Así el margen histórico no cambia si después sube el costo del producto.
- `ALERTA_STOCK.estado` (`PENDIENTE` / `ATENDIDA`): evita alertas duplicadas.
- `REPORTE_CATEGORIA` (PK `anio, trimestre, id_categoria`): guarda el reporte que antes solo se imprimía en consola.
- `BITACORA_OPERACION`: una fila por **sentencia** sobre `producto` (la escribe el trigger de sentencia).
- FK nuevas: `movimiento_stock → venta`, `auditoria_precio → producto`, `alerta_stock → producto`.

**Tablas complementarias** (completan el negocio; ningún procedimiento, función, package ni trigger depende de ellas):

- `CARGO`: tipos de empleado (jefe de sucursal, vendedor, cajero, bodeguero) con `sueldo_base` y `comision_pct`.
- `EMPLEADO`: personal de cada sucursal; `id_jefe` es una FK a la misma tabla.
- `VENTA.id_empleado`: vendedor que atendió la venta. Es **opcional**, así que `pkg_ventas` y `08_carga_volumen.sql` siguen funcionando sin cambios.
- `ORDEN_COMPRA` y `DETALLE_ORDEN_COMPRA`: compras de reposición a proveedores, con estado `PENDIENTE` / `RECIBIDA` / `CANCELADA`.

Imágenes: `diagramas/modelo_relacional_complementarias.png` (tablas complementarias en violeta) y `diagramas/modelo_relacional_cambios.png` (cambios de la EP2 en ámbar).

## Lo más importante del código

### 1. El reporte pasa de bloque anónimo a package

```sql
-- EP1: había que editar las fechas dentro del bloque y ejecutarlo completo
-- EP2: se llama con parámetros y el resultado queda en una tabla
BEGIN
    pkg_reportes.sp_generar_reporte(2026, 3);
    pkg_reportes.sp_mostrar_reporte(2026, 3);
END;
/
```

Lo que antes estaba en el `DECLARE` (RECORD, VARRAY, cursores, funciones auxiliares) ahora es **privado** del cuerpo del package. La prueba P10 demuestra que llamarlo desde fuera da `PLS-00302`.

### 2. Bug corregido en el cursor del reporte

En la EP1 los filtros de estado y fecha estaban en el `LEFT JOIN` de `venta`, pero `detalle_venta` ya se había unido sin filtro: el `SUM` incluía **ventas anuladas y de otros meses**.

```sql
-- EP1 (incorrecto): el filtro no excluye las líneas de detalle
LEFT JOIN detalle_venta d ON d.id_producto = p.id_producto
LEFT JOIN venta v         ON v.id_venta    = d.id_venta
                         AND v.estado      = 'EMITIDA'
                         AND v.fecha_venta BETWEEN p_desde AND p_hasta

-- EP2 (correcto): se filtra primero y después se une
LEFT JOIN (SELECT d.id_producto, d.cantidad, d.precio_unitario,
                  d.descuento_pct, d.costo_unitario
             FROM detalle_venta d
             JOIN venta v ON v.id_venta = d.id_venta
            WHERE v.estado = 'EMITIDA'
              AND v.fecha_venta >= p_desde
              AND v.fecha_venta <  p_hasta) dv
       ON dv.id_producto = p.id_producto
```

También cambia `BETWEEN` por `>= desde AND < hasta`: con `BETWEEN` las ventas del último día después de las 00:00 quedaban fuera.

### 3. El log de errores ya no se pierde

En la EP1, `sp_registrar_log` insertaba el error y luego `RAISE`; si el programa que llamaba hacía `ROLLBACK`, el registro desaparecía.

```sql
WHEN OTHERS THEN
    ROLLBACK;                         -- 1. deshace lo que quedó a medias
    sp_registrar_log('pkg_ventas.sp_cerrar_venta', SQLCODE, SQLERRM);
    COMMIT;                           -- 2. confirma solo el log (línea nueva)
    RAISE;                            -- 3. avisa al que llamó
```

### 4. Una función privada no se puede usar dentro de SQL

```sql
-- No compila (PLS-00231): fn_siguiente_linea es privada del package
INSERT INTO detalle_venta (...) VALUES (p_id_venta, fn_siguiente_linea(p_id_venta), ...);

-- Solución: se asigna antes a una variable
v_linea := fn_siguiente_linea(p_id_venta);
INSERT INTO detalle_venta (...) VALUES (p_id_venta, v_linea, ...);
```

### 5. Triggers de sentencia (nuevos)

```sql
CREATE OR REPLACE TRIGGER trg_bloquea_borrado_venta
BEFORE DELETE ON venta              -- sin FOR EACH ROW: se dispara una vez
BEGIN
    RAISE_APPLICATION_ERROR(-20012,
        'Las ventas no se eliminan. Use pkg_ventas.sp_anular_venta.');
END;
/
```

Por eso `pkg_ventas` ahora tiene `sp_anular_venta`: devuelve el stock y cambia el estado a `ANULADA`.

## Códigos de error

| Código | Origen | Nuevo |
|---|---|---|
| -20001 a -20004 | `pkg_ventas` | — |
| -20005, -20006 | `pkg_ventas` (venta no está en BORRADOR / solo se anula una EMITIDA) | ✔ |
| -20010, -20011 | triggers de fila | — |
| -20012 | `trg_bloquea_borrado_venta` | ✔ |
| -20020, -20021 | `sp_ajustar_precios` | ✔ |
| -20030 | `pkg_reportes` (trimestre inválido) | ✔ |

## Se mantiene igual

Caso de negocio, datos de ejemplo, nombres de tablas y objetos de la EP1, cifras del reporte 2026-T3 ($7.055.044 en 85 unidades) y estilo de código simple (sin `PRAGMA`, `DETERMINISTIC` ni SQL dinámico).
