---- Insertar Datos de Prueba Tablas RetailMan-----

--TABLA CATEGORIA--
INSERT INTO CATEGORIA (code, name ,level_no,status)
VALUES( 'CAT001', 'Cuidado Personal', 1, 'ACTIVE');

INSERT INTO CATEGORIA (code, name,level_no,parent_id,status)
VALUES( 'CAT002', 'Afeitadoras', 2,1, 'ACTIVE');

INSERT INTO CATEGORIA (code, name,level_no,status)
VALUES( 'CAT003', 'Abarrotes', 1, 'ACTIVE');

INSERT INTO CATEGORIA (code, name,level_no,parent_id,status)
VALUES( 'CAT004', 'Enlatados', 2,3, 'ACTIVE');

--TABLA CANAL--

INSERT INTO CANAL (code, name)
VALUES ('MD','MODERNO');

INSERT INTO CANAL (code, name)
VALUES ('TR','TRADICIONAL');

--TABLA FABRICANTE--

INSERT INTO FABRICANTE (name, country_code)
VALUES ('PROCTER Y GAMBLE','CR');

INSERT INTO FABRICANTE (name, country_code)
VALUES ('OTIS MACCALISTER','GT');

-- FORMATO --

INSERT INTO FORMATO (code, name)
VALUES ('DS','Descuentos');

INSERT INTO FORMATO (code, name)
VALUES ('BD','Bodega');

INSERT INTO FORMATO (code, name)
VALUES ('SP','Supermercado');

INSERT INTO FORMATO (code, name)
VALUES ('HP','Hipermercado');


--MARCA---
INSERT INTO MARCA (manufacturer_id,name, status)
VALUES (1, 'La Sirena','ACTIVE');

INSERT INTO MARCA (manufacturer_id,name, status)
VALUES (2, 'Gillette','ACTIVE');


-- MERCADO-- 
INSERT INTO MERCADO (iso_code,name)
VALUES ('CR','Costa Rica');

INSERT INTO MERCADO (iso_code,name)
VALUES ('GT','Guatemala');

INSERT INTO MERCADO (iso_code,name)
VALUES ('SV','El Salvador');


----SKU----

-- La Sirena

INSERT INTO SKU (SKU_CODE,BRAND_ID,DESCRIPTION,NET_CONTENT,UOM,PRESENTATION,STATUS)
VALUES ( 'SKU001', 1,'Atun en Agua',140,'GR','Lata','ACTIVE');

INSERT INTO SKU (  SKU_CODE, BRAND_ID, DESCRIPTION, NET_CONTENT, UOM, PRESENTATION, STATUS)
VALUES ( 'SKU002', 1, 'Maiz Dulce', 300, 'GR', 'Lata', 'ACTIVE');

-- Procter

INSERT INTO SKU ( SKU_CODE,  BRAND_ID,  DESCRIPTION, NET_CONTENT, UOM, PRESENTATION, STATUS)
VALUES ( 'SKU003', 2, 'Gillette Mach3', 1,  'UND', 'Unidad', 'ACTIVE');


--PRODUCTO_CATEGORIA---

INSERT INTO producto_categoria (product_id,category_id)
VALUES (1,4);

INSERT INTO producto_categoria (product_id,category_id)
VALUES (2,4);

INSERT INTO producto_categoria (product_id,category_id)
VALUES (3,2);

---- PRODUCTOS_GTIN--

INSERT INTO PRODUCTOS_GTIN
VALUES ( 1, '744100100001');

INSERT INTO PRODUCTOS_GTIN
VALUES ( 2,'744100100002');

INSERT INTO PRODUCTOS_GTIN
VALUES ( 3,'750100100003');


--- RETAILER-- 

INSERT INTO RETAILER (MARKET_ID, CODE, NAME)
VALUES (1, 'WMCR', 'Walmart Costa Rica');

INSERT INTO RETAILER (MARKET_ID, CODE, NAME)
VALUES (1, 'PRC', 'PriceSmart Costa Rica');

INSERT INTO RETAILER (MARKET_ID, CODE, NAME)
VALUES (2, 'GTAGT', 'GTA Guatemala');

INSERT INTO RETAILER (MARKET_ID, CODE, NAME)
VALUES (3, 'SUPS', 'Super Selectos');


---RETAILER_FORMATO--

INSERT INTO RETAILER_FORMATO (RETAILER_ID, FORMAT_ID, NAME, STATUS)
VALUES (1,1, 'Walmart Descuentos','ACTIVE');

INSERT INTO RETAILER_FORMATO (RETAILER_ID, FORMAT_ID, NAME, STATUS)
VALUES (1,2, 'Walmart Bodega','ACTIVE');

INSERT INTO RETAILER_FORMATO (RETAILER_ID, FORMAT_ID, NAME, STATUS)
VALUES (1,3, 'Walmart Supermercados','ACTIVE');

INSERT INTO RETAILER_FORMATO (RETAILER_ID, FORMAT_ID, NAME, STATUS)
VALUES (1,4, 'Walmart Hipermercados','ACTIVE');


-- PUNTO DE VENTA--

INSERT INTO punto_venta (retailer_id,market_id, channel_id,code,name,zone, address, status)
VALUES (1,1,1,'MXM01','Más x menos Santa Ana', 'Santa Ana', 'Pozos de Santa Ana', 'ACTIVE');

INSERT INTO punto_venta (retailer_id,market_id, channel_id,code,name,zone, address, status)
VALUES (1,1,1,'WM01','Walmart Escazu', 'Escazu', 'San Rafael de Escazu', 'ACTIVE');

commit;

