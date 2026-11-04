# 📦 TECNOPARTS SpA — Sistema de Gestión de Ventas e Inventarios

<div align="center">

![Oracle](https://img.shields.io/badge/Oracle-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![PL/SQL](https://img.shields.io/badge/PL%2FSQL-336791?style=for-the-badge&logo=oracle&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-DD6B20?style=for-the-badge&logo=databricks&logoColor=white)
![SQL Developer](https://img.shields.io/badge/SQL%20Developer-4479A1?style=for-the-badge&logo=oracle&logoColor=white)

![Etapa](https://img.shields.io/badge/Etapa-Evaluación%20Parcial%202-success?style=flat-square)
![Curso](https://img.shields.io/badge/Curso-BDY1103%20%7C%20Taller%20de%20BD-informational?style=flat-square)
![Scripts](https://img.shields.io/badge/Scripts-9%20módulos%20SQL-blueviolet?style=flat-square)
![Tablas](https://img.shields.io/badge/Tablas-18-orange?style=flat-square)

</div>

> **EP2:** la lógica que en la EP1 vivía en un bloque anónimo ahora es una **solución integral** con **7 funciones, 4 procedimientos, 2 packages y 5 triggers** que trabajan juntos. Los cambios respecto a la EP1 están en [`CAMBIOS.md`](CAMBIOS.md).

---

## 🧭 Índice de Archivos

> **Orden de ejecución obligatorio.** En SQL Developer, sobre un esquema vacío, abrir `00_instalar.sql` y ejecutarlo con **F5** (Run Script). Después, ejecutar el 06, el 07 y, si se quiere, el 08.

| N° | Archivo | Rol en el sistema |
|:--:|---------|-------------------|
| 0️⃣ | `00_instalar.sql` | Script maestro: ejecuta del 01 al 05 y verifica que no haya objetos inválidos |
| 1️⃣ | `01_crear_tablas.sql` | 18 tablas (4 complementarias), restricciones, 7 secuencias e índices |
| 2️⃣ | `02_poblar_datos.sql` | Datos de demostración con fechas fijas de 2026 |
| 3️⃣ | `03_funciones_procedimientos.sql` | 7 funciones y 4 procedimientos, con y sin parámetros |
| 4️⃣ | `04_packages.sql` | `pkg_ventas` y `pkg_reportes`, con elementos públicos y privados |
| 5️⃣ | `05_triggers.sql` | 3 triggers de fila y 2 de sentencia |
| 6️⃣ | `06_ejecutar_reporte.sql` | Genera el reporte 2026-T3 desde PL/SQL y lo consulta con SQL |
| 7️⃣ | `07_pruebas.sql` | 17 pruebas según la guía de la EP2 |
| 8️⃣ | `08_carga_volumen.sql` | *(Opcional)* 1.240 ventas de 2025 para demostrar procesamiento masivo |

---

## 🗂️ Modelo de datos (18 tablas)

![Modelo relacional](diagramas/modelo_relacional_complementarias.png)

| Grupo | Tablas |
|-------|--------|
| **Transaccional** | `venta`, `detalle_venta` |
| **Maestro** | `producto`, `categoria`, `proveedor`, `cliente`, `sucursal`, `meta_categoria` |
| **Resultados** | `reporte_categoria` — la llena `pkg_reportes` |
| **Trazabilidad** | `movimiento_stock`, `auditoria_precio`, `alerta_stock`, `bitacora_operacion`, `log_error` |
| **Complementarias** 🟣 | `cargo`, `empleado`, `orden_compra`, `detalle_orden_compra` |

> 🟣 Las tablas **complementarias** completan el negocio (personal, vendedor de cada venta y órdenes de compra a proveedores), pero **ningún procedimiento, función, package ni trigger depende de ellas**. `venta.id_empleado` es opcional.

---

# 📄 Detalle de los Archivos

## 1️⃣ `01_crear_tablas.sql` — Esquema

| Aspecto | Detalle |
|---------|---------|
| 🆕 **Nuevo en EP2** | `detalle_venta.costo_unitario` (costo histórico, lo completa un trigger) · `alerta_stock.estado` · tablas `reporte_categoria` y `bitacora_operacion` · FK que faltaban |
| 🟣 **Complementarias** | `cargo` (sueldo base y comisión) · `empleado` (con `id_jefe` → FK a la misma tabla) · `orden_compra` + `detalle_orden_compra` |
| 🔢 **Secuencias (7)** | `seq_venta`, `seq_movimiento`, `seq_auditoria`, `seq_alerta`, `seq_log`, `seq_bitacora`, `seq_orden` — parten en 100 |

## 2️⃣ `02_poblar_datos.sql` — Datos de demostración

| Aspecto | Detalle |
|---------|---------|
| 📦 **Volumen** | 10 categorías · 5 proveedores · 31 productos · 12 clientes · 4 sucursales · 21 ventas · 47 líneas · 4 cargos · 10 empleados · 2 órdenes de compra |
| 🌟 **Casos de borde** | Categoría 9 sin meta y 7 con meta en cero · ventas de junio (fuera del trimestre) · una venta ANULADA · 3 productos bajo stock crítico |
| ⚠️ **Orden crítico** | Corre **antes** de los triggers, para que la carga histórica no descuente stock |

## 3️⃣ `03_funciones_procedimientos.sql` — Funciones y procedimientos

| Tipo | Sin parámetros | Con parámetros |
|------|----------------|----------------|
| 🔢 **Funciones (7)** | `fn_productos_criticos` · `fn_venta_neta_total` | `fn_margen_pct` · `fn_descuento_cliente` · `fn_neto_venta` · `fn_total_venta` · `fn_venta_neta_periodo` |
| ⚙️ **Procedimientos (4)** | `sp_generar_alertas_stock` · `sp_recalcular_totales` | `sp_ajustar_precios` · `sp_registrar_log` |

> 🛡️ Patrón de errores: `ROLLBACK → sp_registrar_log → COMMIT → RAISE`. Nada queda a medias y el error queda registrado.

## 4️⃣ `04_packages.sql` — Packages

| Package | Público (especificación) | Privado (solo en el cuerpo) |
|---------|--------------------------|-----------------------------|
| 🛒 `pkg_ventas` | `c_iva` · 3 excepciones · `sp_registrar_venta` · `sp_agregar_linea` · `sp_cerrar_venta` · `sp_anular_venta` | `e_venta_no_editable` · `fn_siguiente_linea` · `sp_validar_borrador` |
| 📈 `pkg_reportes` | `e_trimestre_invalido` · `sp_generar_reporte` · `sp_mostrar_reporte` · `fn_cumplimiento` | `t_resumen` (RECORD) · `t_metas` (VARRAY) · cursores · `fn_calcular_margen` · `fn_meta_trimestre` · `sp_rango_trimestre` |

> 🔒 Llamar a un elemento privado desde fuera da **PLS-00302** (prueba P10).

## 5️⃣ `05_triggers.sql` — Triggers

| Nivel | Trigger | Qué hace |
|-------|---------|----------|
| Fila | `trg_valida_detalle` | BEFORE INSERT: valida stock (−20010) y fija `:NEW.costo_unitario` |
| Fila | `trg_descuenta_stock` | AFTER INSERT: descuenta stock y registra el movimiento |
| Fila | `trg_audita_precio` | BEFORE UPDATE: bloquea precio bajo costo (−20011) y audita `:OLD` → `:NEW` |
| Sentencia | `trg_bloquea_borrado_venta` | BEFORE DELETE: las ventas no se borran (−20012), se anulan |
| Sentencia | `trg_bitacora_producto` | AFTER INSERT/DELETE/UPDATE: una fila por sentencia en la bitácora |

## 6️⃣ – 8️⃣ Ejecución y pruebas

| Archivo | Detalle |
|---------|---------|
| `06_ejecutar_reporte.sql` | `pkg_reportes.sp_generar_reporte(2026, 3)` + consulta con SQL + control (suma del reporte = `fn_venta_neta_periodo`) |
| `07_pruebas.sql` | P1–P17: procedimientos, funciones, casos límite, flujo completo, público/privado, fila vs sentencia, objetos válidos. **P10 falla a propósito.** |
| `08_carga_volumen.sql` | Opcional: 1.240 ventas de 2025, reportes T1–T4 y consulta de control |

---

## 🔗 Cadena de Dependencias

```text
00_instalar.sql
 ├──▶ 01_crear_tablas.sql            (18 tablas + secuencias + índices)
 ├──▶ 02_poblar_datos.sql            (datos)                ⚠ antes de triggers
 ├──▶ 03_funciones_procedimientos.sql                       ⚠ antes de packages
 ├──▶ 04_packages.sql                (pkg_ventas, pkg_reportes: usan 03)
 └──▶ 05_triggers.sql                (3 de fila + 2 de sentencia)
        ▼
 06_ejecutar_reporte.sql             (reporte 2026-T3)
 07_pruebas.sql                      (17 pruebas)
 08_carga_volumen.sql                (opcional)
```

---

<div align="center">

**TecnoParts SpA** · BDY1103 — Taller de Base de Datos · Ignacio Moya · Bryan Burgos · Felipe Rios · Rodrigo Godoy

</div>
