-- ============================================================================
-- TecnoParts SpA  |  02_poblar_datos.sql   (EP2)
-- Datos de demostracion. Se ejecuta ANTES de crear los triggers (script 05),
-- para que la carga historica no dispare el descuento automatico de stock.
-- Las fechas son fijas (2026) para que el reporte entregue siempre el mismo
-- resultado y se pueda comparar con la tabla del informe.
-- ============================================================================
SET DEFINE OFF

INSERT INTO sucursal VALUES (1, 'TecnoParts Providencia', 'Providencia');
INSERT INTO sucursal VALUES (2, 'TecnoParts Maipu',       'Maipu');
INSERT INTO sucursal VALUES (3, 'TecnoParts Vina',        'Vina del Mar');
INSERT INTO sucursal VALUES (4, 'Canal Online',           'E-commerce');

INSERT INTO proveedor VALUES (1, 'Distribuidora Andes Tech', 'ventas@andestech.cl');
INSERT INTO proveedor VALUES (2, 'ImportaPC Ltda',           'contacto@importapc.cl');
INSERT INTO proveedor VALUES (3, 'Pacific Components SpA',   'ordenes@pacific.cl');
INSERT INTO proveedor VALUES (4, 'Global Hardware Import',   'sales@globalhw.com');
INSERT INTO proveedor VALUES (5, 'Nortec Distribucion',      'nortec@nortec.cl');

-- Tablas complementarias: tipos de empleado y personal por sucursal.
-- No las usan los procedimientos, packages ni triggers.
INSERT INTO cargo VALUES (1, 'JEFE DE SUCURSAL', 1400000, 0);
INSERT INTO cargo VALUES (2, 'VENDEDOR',          650000, 2);
INSERT INTO cargo VALUES (3, 'CAJERO',            600000, 0);
INSERT INTO cargo VALUES (4, 'BODEGUERO',         620000, 0);

-- Primero los jefes (id_jefe NULL), despues el personal que depende de ellos
INSERT INTO empleado VALUES ( 1,'10.100.100-1','Paula',   'Navarro', 'pnavarro@tecnoparts.cl','+56911110001',TO_DATE('01/03/2022','DD/MM/YYYY'),1,1,NULL,'S');
INSERT INTO empleado VALUES ( 4,'10.400.400-4','Jorge',   'Salinas', 'jsalinas@tecnoparts.cl','+56911110004',TO_DATE('15/06/2022','DD/MM/YYYY'),1,2,NULL,'S');
INSERT INTO empleado VALUES ( 6,'10.600.600-6','Carla',   'Vergara', 'cvergara@tecnoparts.cl','+56911110006',TO_DATE('01/02/2023','DD/MM/YYYY'),1,3,NULL,'S');
INSERT INTO empleado VALUES ( 2,'10.200.200-2','Tomas',   'Riquelme','triquelme@tecnoparts.cl','+56911110002',TO_DATE('10/01/2024','DD/MM/YYYY'),2,1,1,'S');
INSERT INTO empleado VALUES ( 3,'10.300.300-3','Fernanda','Pizarro', 'fpizarro@tecnoparts.cl','+56911110003',TO_DATE('05/05/2024','DD/MM/YYYY'),3,1,1,'S');
INSERT INTO empleado VALUES ( 5,'10.500.500-5','Benjamin','Araya',   'baraya@tecnoparts.cl',  '+56911110005',TO_DATE('20/08/2023','DD/MM/YYYY'),2,2,4,'S');
INSERT INTO empleado VALUES ( 7,'10.700.700-7','Josefa',  'Contreras','jcontreras@tecnoparts.cl','+56911110007',TO_DATE('03/03/2025','DD/MM/YYYY'),2,3,6,'S');
INSERT INTO empleado VALUES ( 8,'10.800.800-8','Martin',  'Espinoza','mespinoza@tecnoparts.cl','+56911110008',TO_DATE('12/11/2024','DD/MM/YYYY'),2,4,1,'S');
INSERT INTO empleado VALUES ( 9,'10.900.900-9','Lucas',   'Bravo',   'lbravo@tecnoparts.cl',  '+56911110009',TO_DATE('01/07/2023','DD/MM/YYYY'),4,1,1,'S');
INSERT INTO empleado VALUES (10,'11.000.000-K','Isidora', 'Morales', 'imorales@tecnoparts.cl','+56911110010',TO_DATE('18/09/2025','DD/MM/YYYY'),4,2,4,'N');

-- La categoria 9 queda sin meta cargada y la 7 con metas en cero:
-- los dos casos que ejercitan las excepciones del bloque anonimo.
INSERT INTO categoria VALUES (1, 'Procesadores',        'S');
INSERT INTO categoria VALUES (2, 'Tarjetas Graficas',   'S');
INSERT INTO categoria VALUES (3, 'Placas Madre',        'S');
INSERT INTO categoria VALUES (4, 'Memorias RAM',        'S');
INSERT INTO categoria VALUES (5, 'Almacenamiento',      'S');
INSERT INTO categoria VALUES (6, 'Fuentes de Poder',    'S');
INSERT INTO categoria VALUES (7, 'Gabinetes',           'S');
INSERT INTO categoria VALUES (8, 'Perifericos',         'S');
INSERT INTO categoria VALUES (9, 'Refrigeracion',       'S');
INSERT INTO categoria VALUES (10,'Cables y Adaptadores','N');

-- stock_actual se carga con el stock INICIAL y al final del script
-- se le descuenta lo vendido.
-- EP2: 104, 202 y 303 tienen un stock_critico que los deja EN o BAJO el
-- minimo despues de las ventas, para que sp_generar_alertas_stock tenga
-- casos que procesar.
INSERT INTO producto VALUES (101,'CPU-R5-5600',   'AMD Ryzen 5 5600',            1,1,  95000, 139990, 25, 5,'S');
INSERT INTO producto VALUES (102,'CPU-R7-5800X',  'AMD Ryzen 7 5800X',           1,1, 155000, 219990, 12, 4,'S');
INSERT INTO producto VALUES (103,'CPU-I5-12400F', 'Intel Core i5-12400F',        1,2, 105000, 149990, 18, 5,'S');
INSERT INTO producto VALUES (104,'CPU-I7-13700K', 'Intel Core i7-13700K',        1,2, 290000, 399990,  6, 5,'S');
INSERT INTO producto VALUES (201,'GPU-RTX4060',   'GeForce RTX 4060 8GB',        2,3, 320000, 429990, 10, 3,'S');
INSERT INTO producto VALUES (202,'GPU-RTX4070',   'GeForce RTX 4070 12GB',       2,3, 520000, 689990,  5, 4,'S');
INSERT INTO producto VALUES (203,'GPU-RX7600',    'Radeon RX 7600 8GB',          2,4, 270000, 359990,  8, 3,'S');
INSERT INTO producto VALUES (204,'GPU-GTX1650',   'GeForce GTX 1650 4GB',        2,4, 150000, 199990, 14, 4,'S');
INSERT INTO producto VALUES (301,'MB-B550M',      'Placa Madre B550M AM4',       3,1,  68000,  99990, 20, 5,'S');
INSERT INTO producto VALUES (302,'MB-B660M',      'Placa Madre B660M LGA1700',   3,2,  72000, 104990, 15, 5,'S');
INSERT INTO producto VALUES (303,'MB-X670E',      'Placa Madre X670E AM5',       3,1, 230000, 319990,  4, 3,'S');
INSERT INTO producto VALUES (401,'RAM-16GB-3200', 'Memoria DDR4 16GB 3200MHz',   4,5,  32000,  49990, 40,10,'S');
INSERT INTO producto VALUES (402,'RAM-32GB-3600', 'Memoria DDR4 32GB 3600MHz',   4,5,  68000,  99990, 22, 8,'S');
INSERT INTO producto VALUES (403,'RAM-8GB-2666',  'Memoria DDR4 8GB 2666MHz',    4,5,  17000,  27990, 35,10,'S');
INSERT INTO producto VALUES (501,'SSD-NVME-1TB',  'SSD NVMe M.2 1TB',            5,3,  48000,  74990, 30, 8,'S');
INSERT INTO producto VALUES (502,'SSD-SATA-480',  'SSD SATA 2.5 480GB',          5,3,  21000,  32990, 45,10,'S');
INSERT INTO producto VALUES (503,'HDD-2TB',       'Disco Duro 2TB 7200rpm',      5,4,  38000,  59990, 18, 6,'S');
INSERT INTO producto VALUES (504,'SSD-NVME-2TB',  'SSD NVMe M.2 2TB',            5,3,  95000, 139990,  9, 4,'S');
INSERT INTO producto VALUES (601,'PSU-600W',      'Fuente 600W 80 Plus Bronze',  6,3,  34000,  52990, 26, 8,'S');
INSERT INTO producto VALUES (602,'PSU-750W',      'Fuente 750W 80 Plus Gold',    6,3,  62000,  89990, 14, 5,'S');
INSERT INTO producto VALUES (603,'PSU-850W',      'Fuente 850W 80 Plus Gold',    6,3,  82000, 119990,  7, 3,'S');
INSERT INTO producto VALUES (701,'CASE-ATX-RGB',  'Gabinete ATX RGB',            7,4,  29000,  45990, 20, 6,'S');
INSERT INTO producto VALUES (702,'CASE-MATX',     'Gabinete Micro-ATX Negro',    7,4,  19000,  29990, 25, 8,'S');
INSERT INTO producto VALUES (703,'CASE-ATX-VID',  'Gabinete ATX Vidrio',         7,4,  42000,  64990, 10, 4,'S');
INSERT INTO producto VALUES (801,'TEC-MEC-RGB',   'Teclado Mecanico RGB',        8,5,  22000,  36990, 30,10,'S');
INSERT INTO producto VALUES (802,'MOUSE-GAMER',   'Mouse Gamer 12000 DPI',       8,5,   9000,  16990, 50,15,'S');
INSERT INTO producto VALUES (803,'AUDIF-7.1',     'Audifonos Gamer 7.1',         8,5,  18000,  29990, 28,10,'S');
INSERT INTO producto VALUES (804,'MONITOR-24',    'Monitor 24 pulgadas 144Hz',   8,2,  98000, 149990, 12, 4,'S');
INSERT INTO producto VALUES (805,'CABLE-HDMI',    'Cable HDMI 2.1 de 2 metros',  8,5,   1800,   4990,120,30,'S');
INSERT INTO producto VALUES (901,'COOLER-AIR',    'Cooler CPU Aire 120mm',       9,3,  18000,  29990, 18, 6,'S');
INSERT INTO producto VALUES (902,'AIO-240-RGB',   'Refrigeracion Liquida 240',   9,3,  62000,  94990,  8, 3,'S');

INSERT INTO cliente VALUES ( 1,'11.111.111-1','Rodrigo Fuentes Silva',  'NORMAL');
INSERT INTO cliente VALUES ( 2,'12.222.222-2','Camila Rojas Perez',     'PREFERENTE');
INSERT INTO cliente VALUES ( 3,'76.900.100-3','Soluciones TI SpA',      'EMPRESA');
INSERT INTO cliente VALUES ( 4,'13.444.444-4','Matias Herrera Lopez',   'NORMAL');
INSERT INTO cliente VALUES ( 5,'14.555.555-5','Valentina Munoz Diaz',   'NORMAL');
INSERT INTO cliente VALUES ( 6,'15.666.666-6','Ignacio Torres Vega',    'PREFERENTE');
INSERT INTO cliente VALUES ( 7,'77.800.200-7','Colegio San Pedro',      'EMPRESA');
INSERT INTO cliente VALUES ( 8,'16.888.888-8','Francisca Soto Ramirez', 'NORMAL');
INSERT INTO cliente VALUES ( 9,'17.999.999-9','Sebastian Castro Pino',  'PREFERENTE');
INSERT INTO cliente VALUES (10,'18.101.010-0','Antonia Guzman Reyes',   'NORMAL');
INSERT INTO cliente VALUES (11,'78.700.300-5','Estudio Contable Norte', 'EMPRESA');
INSERT INTO cliente VALUES (12,'19.121.212-1','Diego Alarcon Moya',     'NORMAL');

INSERT INTO meta_categoria VALUES (1, 2026, 2500000, 2500000, 1200000, 3200000);
INSERT INTO meta_categoria VALUES (2, 2026, 4000000, 4000000, 1800000, 5000000);
INSERT INTO meta_categoria VALUES (3, 2026, 1200000, 1200000,  800000, 1500000);
INSERT INTO meta_categoria VALUES (4, 2026,  900000,  900000,  700000, 1200000);
INSERT INTO meta_categoria VALUES (5, 2026, 1500000, 1500000,  800000, 1900000);
INSERT INTO meta_categoria VALUES (6, 2026,  700000,  700000,  400000,  900000);
INSERT INTO meta_categoria VALUES (7, 2026,       0,       0,       0,       0);
INSERT INTO meta_categoria VALUES (8, 2026,  800000,  800000,  600000, 1100000);

-- Ventas del tercer trimestre de 2026 (las que entran en el reporte)
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 1, 1,1,TO_DATE('11/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 2, 2,1,TO_DATE('16/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 3, 3,4,TO_DATE('18/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 4, 4,2,TO_DATE('21/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 5, 5,3,TO_DATE('23/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 6, 6,4,TO_DATE('26/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 7, 7,1,TO_DATE('29/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 8, 8,2,TO_DATE('31/08/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES ( 9, 9,4,TO_DATE('02/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (10,10,3,TO_DATE('05/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (11,11,1,TO_DATE('08/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (12,12,4,TO_DATE('10/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (13, 1,2,TO_DATE('12/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (14, 3,4,TO_DATE('14/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (15, 5,1,TO_DATE('15/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (16, 7,3,TO_DATE('16/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (17, 9,4,TO_DATE('17/09/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (18, 2,1,TO_DATE('19/09/2026','DD/MM/YYYY'),'EMITIDA');
-- Dos ventas del trimestre anterior: no deben aparecer en el reporte
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (19, 4,1,TO_DATE('11/06/2026','DD/MM/YYYY'),'EMITIDA');
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (20, 6,4,TO_DATE('13/06/2026','DD/MM/YYYY'),'EMITIDA');
-- Una venta anulada: el cursor del reporte solo considera estado EMITIDA
INSERT INTO venta (id_venta,id_cliente,id_sucursal,fecha_venta,estado) VALUES (21,10,1,TO_DATE('18/09/2026','DD/MM/YYYY'),'ANULADA');

-- descuento_pct: NORMAL 0 | PREFERENTE 5 | EMPRESA 12
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 1,1,101,1,139990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 1,2,301,1, 99990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 1,3,401,2, 49990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 2,1,201,1,429990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 2,2,602,1, 89990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 3,1,103,3,149990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 3,2,302,3,104990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 3,3,501,3, 74990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 4,1,802,2, 16990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 4,2,801,1, 36990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 4,3,805,3,  4990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 5,1,204,1,199990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 5,2,601,1, 52990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 6,1,202,1,689990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 6,2,303,1,319990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 6,3,402,2, 99990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 7,1,502,5, 32990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 7,2,503,2, 59990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 8,1,701,1, 45990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 8,2,601,1, 52990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 8,3,403,2, 27990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 9,1,104,1,399990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES ( 9,2,603,1,119990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (10,1,804,1,149990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (10,2,803,1, 29990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (11,1,501,4, 74990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (11,2,401,6, 49990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (11,3,805,10, 4990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (12,1,203,1,359990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (12,2,702,1, 29990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (13,1,102,1,219990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (13,2,402,1, 99990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (14,1,302,2,104990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (14,2,103,2,149990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (15,1,504,1,139990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (15,2,703,1, 64990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (16,1,801,4, 36990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (16,2,802,4, 16990,12);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (17,1,201,1,429990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (17,2,602,1, 89990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (17,3,701,1, 45990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (18,1,901,1, 29990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (18,2,902,1, 94990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (19,1,101,1,139990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (19,2,201,1,429990, 0);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (20,1,501,2, 74990, 5);
INSERT INTO detalle_venta (id_venta,nro_linea,id_producto,cantidad,precio_unitario,descuento_pct) VALUES (21,1,202,1,689990, 0);

-- Costo historico de cada linea (columna nueva en la EP2).
-- En la operacion normal lo completa el trigger trg_valida_detalle; aqui los
-- triggers aun no existen, por eso se copia desde el producto.
UPDATE detalle_venta d
   SET d.costo_unitario = (SELECT p.costo_unitario
                             FROM producto p
                            WHERE p.id_producto = d.id_producto);

-- Totales de la cabecera calculados desde el detalle (IVA 19%)
UPDATE venta v
   SET total_neto  = (SELECT ROUND(NVL(SUM(d.cantidad * d.precio_unitario
                             * (1 - d.descuento_pct/100)),0))
                        FROM detalle_venta d WHERE d.id_venta = v.id_venta),
       total_iva   = (SELECT ROUND(NVL(SUM(d.cantidad * d.precio_unitario
                             * (1 - d.descuento_pct/100)),0) * 0.19)
                        FROM detalle_venta d WHERE d.id_venta = v.id_venta),
       total_bruto = (SELECT ROUND(NVL(SUM(d.cantidad * d.precio_unitario
                             * (1 - d.descuento_pct/100)),0) * 1.19)
                        FROM detalle_venta d WHERE d.id_venta = v.id_venta);

-- Movimientos de inventario: la entrada inicial de cada producto
INSERT INTO movimiento_stock (id_movimiento, id_producto, tipo_movimiento,
                              cantidad, fecha, id_venta)
SELECT seq_movimiento.NEXTVAL, p.id_producto, 'ENTRADA', p.stock_actual,
       TO_DATE('01/07/2026','DD/MM/YYYY'), NULL
  FROM producto p WHERE p.stock_actual > 0;

-- y la salida de cada linea vendida
INSERT INTO movimiento_stock (id_movimiento, id_producto, tipo_movimiento,
                              cantidad, fecha, id_venta)
SELECT seq_movimiento.NEXTVAL, d.id_producto, 'SALIDA', d.cantidad,
       v.fecha_venta, v.id_venta
  FROM detalle_venta d
  JOIN venta v ON v.id_venta = d.id_venta
 WHERE v.estado = 'EMITIDA';

-- Dos ajustes por merma, para que el tercer nivel del reporte tenga variedad
INSERT INTO movimiento_stock (id_movimiento, id_producto, tipo_movimiento, cantidad, fecha, id_venta)
VALUES (seq_movimiento.NEXTVAL, 805, 'AJUSTE', 2, TO_DATE('12/09/2026','DD/MM/YYYY'), NULL);
INSERT INTO movimiento_stock (id_movimiento, id_producto, tipo_movimiento, cantidad, fecha, id_venta)
VALUES (seq_movimiento.NEXTVAL, 502, 'AJUSTE', 1, TO_DATE('10/09/2026','DD/MM/YYYY'), NULL);

-- Stock final = stock inicial menos lo vendido
UPDATE producto p
   SET p.stock_actual = p.stock_actual -
       NVL((SELECT SUM(d.cantidad)
              FROM detalle_venta d
              JOIN venta v ON v.id_venta = d.id_venta
             WHERE d.id_producto = p.id_producto
               AND v.estado = 'EMITIDA'), 0);

-- Complementaria: vendedor que atendio cada venta (uno por sucursal)
UPDATE venta
   SET id_empleado = CASE id_sucursal WHEN 1 THEN 2
                                      WHEN 2 THEN 5
                                      WHEN 3 THEN 7
                                      ELSE 8 END;

-- Complementaria: ordenes de compra para reponer los productos criticos.
-- Quedan PENDIENTES: no modifican el stock.
INSERT INTO orden_compra VALUES (1, 2, 9, TO_DATE('25/09/2026','DD/MM/YYYY'), NULL, 'PENDIENTE', 1450000);
INSERT INTO detalle_orden_compra VALUES (1, 104, 5, 290000);
INSERT INTO orden_compra VALUES (2, 1, 9, TO_DATE('25/09/2026','DD/MM/YYYY'), NULL, 'PENDIENTE',  920000);
INSERT INTO detalle_orden_compra VALUES (2, 303, 4, 230000);

COMMIT;

PROMPT Datos cargados.
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'producto',         COUNT(*) FROM producto
UNION ALL SELECT 'cliente',          COUNT(*) FROM cliente
UNION ALL SELECT 'venta',            COUNT(*) FROM venta
UNION ALL SELECT 'detalle_venta',    COUNT(*) FROM detalle_venta
UNION ALL SELECT 'movimiento_stock', COUNT(*) FROM movimiento_stock
UNION ALL SELECT 'empleado',         COUNT(*) FROM empleado
UNION ALL SELECT 'orden_compra',     COUNT(*) FROM orden_compra;
