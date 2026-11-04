-- ============================================================================
-- TecnoParts SpA  |  BDY1103 - Taller de Base de Datos  |  Evaluacion Parcial 2
-- 01_crear_tablas.sql   Creacion del esquema (18 tablas)
-- Ejecutar en un esquema de practica vacio.
--
-- Cambios respecto a la EP1:
--   * DETALLE_VENTA.costo_unitario   costo historico, lo completa un trigger
--   * ALERTA_STOCK.estado            permite re-ejecutar el proceso de alertas
--   * REPORTE_CATEGORIA              tabla nueva: resultado del reporte
--   * BITACORA_OPERACION             tabla nueva: la llenan triggers de sentencia
--   * FK que faltaban en AUDITORIA_PRECIO, ALERTA_STOCK y MOVIMIENTO_STOCK
--   * Tablas complementarias (no las usan los procedimientos, packages ni
--     triggers): CARGO, EMPLEADO, ORDEN_COMPRA, DETALLE_ORDEN_COMPRA y la
--     columna opcional VENTA.id_empleado (vendedor que atendio la venta)
-- ============================================================================
SET DEFINE OFF

-- ----------------------------------------------------------------------------
-- MAESTRAS
-- ----------------------------------------------------------------------------
CREATE TABLE categoria (
    id_categoria NUMBER(4)    PRIMARY KEY,
    nombre       VARCHAR2(50) NOT NULL UNIQUE,
    activo       CHAR(1)      DEFAULT 'S'
                 CONSTRAINT ck_categoria_activo CHECK (activo IN ('S','N'))
);

CREATE TABLE proveedor (
    id_proveedor NUMBER(5)    PRIMARY KEY,
    nombre       VARCHAR2(80) NOT NULL,
    email        VARCHAR2(80)
);

CREATE TABLE producto (
    id_producto    NUMBER(8)     PRIMARY KEY,
    sku            VARCHAR2(30)  NOT NULL UNIQUE,
    nombre         VARCHAR2(120) NOT NULL,
    id_categoria   NUMBER(4)     NOT NULL,
    id_proveedor   NUMBER(5)     NOT NULL,
    costo_unitario NUMBER(12,2)  NOT NULL,
    precio_venta   NUMBER(12,2)  NOT NULL,
    stock_actual   NUMBER(8)     DEFAULT 0,
    stock_critico  NUMBER(8)     DEFAULT 5,
    activo         CHAR(1)       DEFAULT 'S',
    CONSTRAINT ck_producto_costo  CHECK (costo_unitario >= 0),
    CONSTRAINT ck_producto_precio CHECK (precio_venta >= 0),
    CONSTRAINT ck_producto_stock  CHECK (stock_actual >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria),
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor)
        REFERENCES proveedor(id_proveedor)
);

CREATE TABLE cliente (
    id_cliente   NUMBER(8)     PRIMARY KEY,
    rut          VARCHAR2(12)  NOT NULL UNIQUE,
    nombre       VARCHAR2(100) NOT NULL,
    tipo_cliente VARCHAR2(12)  DEFAULT 'NORMAL'
                 CONSTRAINT ck_cliente_tipo
                 CHECK (tipo_cliente IN ('NORMAL','PREFERENTE','EMPRESA'))
);

CREATE TABLE sucursal (
    id_sucursal NUMBER(3)    PRIMARY KEY,
    nombre      VARCHAR2(50) NOT NULL,
    comuna      VARCHAR2(50)
);

-- COMPLEMENTARIA: tipos de empleado (vendedor, cajero, bodeguero, jefe)
CREATE TABLE cargo (
    id_cargo    NUMBER(3)    PRIMARY KEY,
    nombre      VARCHAR2(40) NOT NULL UNIQUE,
    sueldo_base NUMBER(10)   NOT NULL,
    comision_pct NUMBER(4,2) DEFAULT 0,
    CONSTRAINT ck_cargo_sueldo   CHECK (sueldo_base > 0),
    CONSTRAINT ck_cargo_comision CHECK (comision_pct BETWEEN 0 AND 20)
);

-- COMPLEMENTARIA: personal de cada sucursal. id_jefe apunta a otro empleado.
CREATE TABLE empleado (
    id_empleado        NUMBER(6)     PRIMARY KEY,
    rut                VARCHAR2(12)  NOT NULL UNIQUE,
    nombre             VARCHAR2(60)  NOT NULL,
    apellido           VARCHAR2(60)  NOT NULL,
    email              VARCHAR2(80),
    telefono           VARCHAR2(15),
    fecha_contratacion DATE          DEFAULT SYSDATE NOT NULL,
    id_cargo           NUMBER(3)     NOT NULL,
    id_sucursal        NUMBER(3)     NOT NULL,
    id_jefe            NUMBER(6),
    activo             CHAR(1)       DEFAULT 'S'
                       CONSTRAINT ck_empleado_activo CHECK (activo IN ('S','N')),
    CONSTRAINT fk_empleado_cargo    FOREIGN KEY (id_cargo)
        REFERENCES cargo(id_cargo),
    CONSTRAINT fk_empleado_sucursal FOREIGN KEY (id_sucursal)
        REFERENCES sucursal(id_sucursal),
    CONSTRAINT fk_empleado_jefe     FOREIGN KEY (id_jefe)
        REFERENCES empleado(id_empleado)
);

-- ----------------------------------------------------------------------------
-- PARAMETRICA
-- Metas de venta por categoria y anio, una columna por trimestre.
-- ----------------------------------------------------------------------------
CREATE TABLE meta_categoria (
    id_categoria NUMBER(4)    NOT NULL,
    anio         NUMBER(4)    NOT NULL,
    meta_q1      NUMBER(14,2) DEFAULT 0,
    meta_q2      NUMBER(14,2) DEFAULT 0,
    meta_q3      NUMBER(14,2) DEFAULT 0,
    meta_q4      NUMBER(14,2) DEFAULT 0,
    CONSTRAINT pk_meta_categoria PRIMARY KEY (id_categoria, anio),
    CONSTRAINT fk_meta_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
);

-- ----------------------------------------------------------------------------
-- TRANSACCIONALES
-- ----------------------------------------------------------------------------
CREATE TABLE venta (
    id_venta    NUMBER(10)   PRIMARY KEY,
    id_cliente  NUMBER(8)    NOT NULL,
    id_sucursal NUMBER(3)    NOT NULL,
    fecha_venta DATE         DEFAULT SYSDATE NOT NULL,
    total_neto  NUMBER(14,2) DEFAULT 0,
    total_iva   NUMBER(14,2) DEFAULT 0,
    total_bruto NUMBER(14,2) DEFAULT 0,
    estado      VARCHAR2(10) DEFAULT 'BORRADOR'
                CONSTRAINT ck_venta_estado
                CHECK (estado IN ('BORRADOR','EMITIDA','ANULADA')),
    CONSTRAINT fk_venta_cliente  FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente),
    id_empleado NUMBER(6),            -- opcional: vendedor (complementaria)
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal)
        REFERENCES sucursal(id_sucursal),
    CONSTRAINT fk_venta_empleado FOREIGN KEY (id_empleado)
        REFERENCES empleado(id_empleado)
);

-- costo_unitario (NUEVO): costo del producto al momento de vender.
-- Lo completa el trigger trg_valida_detalle; asi el margen historico
-- no cambia cuando cambia el costo actual del producto.
CREATE TABLE detalle_venta (
    id_venta        NUMBER(10)   NOT NULL,
    nro_linea       NUMBER(4)    NOT NULL,
    id_producto     NUMBER(8)    NOT NULL,
    cantidad        NUMBER(6)    NOT NULL,
    precio_unitario NUMBER(12,2) NOT NULL,
    descuento_pct   NUMBER(5,2)  DEFAULT 0,
    costo_unitario  NUMBER(12,2),
    CONSTRAINT pk_detalle_venta PRIMARY KEY (id_venta, nro_linea),
    CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_dcto CHECK (descuento_pct BETWEEN 0 AND 100),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta)
        REFERENCES venta(id_venta),
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);

CREATE TABLE movimiento_stock (
    id_movimiento   NUMBER(12)   PRIMARY KEY,
    id_producto     NUMBER(8)    NOT NULL,
    tipo_movimiento VARCHAR2(10) NOT NULL
                    CONSTRAINT ck_movimiento_tipo
                    CHECK (tipo_movimiento IN ('ENTRADA','SALIDA','AJUSTE')),
    cantidad        NUMBER(8)    NOT NULL,
    fecha           DATE         DEFAULT SYSDATE,
    id_venta        NUMBER(10),
    CONSTRAINT fk_movimiento_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto),
    CONSTRAINT fk_movimiento_venta FOREIGN KEY (id_venta)
        REFERENCES venta(id_venta)
);

-- ----------------------------------------------------------------------------
-- RESULTADOS (NUEVA)
-- La llena pkg_reportes.sp_generar_reporte. Antes el reporte solo se veia
-- en pantalla con DBMS_OUTPUT; ahora queda guardado y se puede consultar
-- con SQL o desde otras aplicaciones.
-- ----------------------------------------------------------------------------
CREATE TABLE reporte_categoria (
    anio             NUMBER(4)    NOT NULL,
    trimestre        NUMBER(1)    NOT NULL,
    id_categoria     NUMBER(4)    NOT NULL,
    unidades         NUMBER(10)   DEFAULT 0,
    venta_neta       NUMBER(14,2) DEFAULT 0,
    costo_total      NUMBER(14,2) DEFAULT 0,
    margen_pct       NUMBER(7,2),
    meta             NUMBER(14,2),
    cumplimiento_pct NUMBER(7,2),
    fecha_generacion DATE         DEFAULT SYSDATE,
    CONSTRAINT pk_reporte_categoria PRIMARY KEY (anio, trimestre, id_categoria),
    CONSTRAINT ck_reporte_trimestre CHECK (trimestre BETWEEN 1 AND 4),
    CONSTRAINT fk_reporte_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
);

-- ----------------------------------------------------------------------------
-- TRAZABILIDAD
-- ----------------------------------------------------------------------------
CREATE TABLE auditoria_precio (
    id_auditoria    NUMBER(12)   PRIMARY KEY,
    id_producto     NUMBER(8)    NOT NULL,
    precio_anterior NUMBER(12,2),
    precio_nuevo    NUMBER(12,2),
    usuario_bd      VARCHAR2(40),
    fecha_cambio    DATE DEFAULT SYSDATE,
    CONSTRAINT fk_auditoria_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);

-- estado (NUEVO): el proceso de alertas no duplica una alerta PENDIENTE.
CREATE TABLE alerta_stock (
    id_alerta     NUMBER(12)   PRIMARY KEY,
    id_producto   NUMBER(8)    NOT NULL,
    stock_actual  NUMBER(8),
    stock_critico NUMBER(8),
    fecha_alerta  DATE         DEFAULT SYSDATE,
    estado        VARCHAR2(10) DEFAULT 'PENDIENTE'
                  CONSTRAINT ck_alerta_estado
                  CHECK (estado IN ('PENDIENTE','ATENDIDA')),
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);

-- NUEVA: una fila por SENTENCIA (no por fila). La llenan los triggers
-- de nivel de sentencia.
CREATE TABLE bitacora_operacion (
    id_bitacora NUMBER(12)   PRIMARY KEY,
    tabla       VARCHAR2(30) NOT NULL,
    operacion   VARCHAR2(30) NOT NULL,
    usuario_bd  VARCHAR2(40),
    fecha       DATE         DEFAULT SYSDATE
);

-- COMPLEMENTARIA: compras de reposicion a proveedores
CREATE TABLE orden_compra (
    id_orden     NUMBER(10)   PRIMARY KEY,
    id_proveedor NUMBER(5)    NOT NULL,
    id_empleado  NUMBER(6)    NOT NULL,      -- quien la solicita
    fecha_orden  DATE         DEFAULT SYSDATE NOT NULL,
    fecha_recepcion DATE,
    estado       VARCHAR2(10) DEFAULT 'PENDIENTE'
                 CONSTRAINT ck_orden_estado
                 CHECK (estado IN ('PENDIENTE','RECIBIDA','CANCELADA')),
    total        NUMBER(14,2) DEFAULT 0,
    CONSTRAINT fk_orden_proveedor FOREIGN KEY (id_proveedor)
        REFERENCES proveedor(id_proveedor),
    CONSTRAINT fk_orden_empleado  FOREIGN KEY (id_empleado)
        REFERENCES empleado(id_empleado)
);

CREATE TABLE detalle_orden_compra (
    id_orden       NUMBER(10)   NOT NULL,
    id_producto    NUMBER(8)    NOT NULL,
    cantidad       NUMBER(6)    NOT NULL,
    costo_unitario NUMBER(12,2) NOT NULL,
    CONSTRAINT pk_detalle_orden PRIMARY KEY (id_orden, id_producto),
    CONSTRAINT ck_detalle_orden_cant CHECK (cantidad > 0),
    CONSTRAINT fk_detorden_orden    FOREIGN KEY (id_orden)
        REFERENCES orden_compra(id_orden),
    CONSTRAINT fk_detorden_producto FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
);

CREATE TABLE log_error (
    id_log       NUMBER(12) PRIMARY KEY,
    origen       VARCHAR2(60),
    codigo_error NUMBER,
    mensaje      VARCHAR2(500),
    fecha        DATE DEFAULT SYSDATE
);

-- ----------------------------------------------------------------------------
-- SECUENCIAS
-- Parten en 100 para no chocar con los identificadores fijos del script 02.
-- ----------------------------------------------------------------------------
CREATE SEQUENCE seq_venta      START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_movimiento START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_auditoria  START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_alerta     START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_log        START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_bitacora   START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_orden      START WITH 100 INCREMENT BY 1;

CREATE INDEX ix_producto_categoria ON producto(id_categoria);
CREATE INDEX ix_detalle_producto   ON detalle_venta(id_producto);
CREATE INDEX ix_venta_fecha        ON venta(fecha_venta, estado);

PROMPT 18 tablas, 7 secuencias e indices creados.
