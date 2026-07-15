---- Procedimientos, Funciones y Vistas asociadas a la Tabla SKU-----

/* ============================================================
   PROYECTO: RetailMan
   MODULO   : Gestion PRODUCTOS = SKUS
   REQ 3    : Registrar Productos
   Autor    : Catalina Mora
   Motor    : Oracle PL/SQL
============================================================ */


----- FUNCIONES -----

--- VALIDACION DE QUE UN PRODUCTO NO EXISTA -----

CREATE OR REPLACE FUNCTION FN_EXISTE_SKU(
    P_SKU_CODE SKU.SKU_CODE%TYPE,
    P_DESCRIPTION SKU.DESCRIPTION%TYPE
)
RETURN NUMBER
AS
    V_EXISTE_SKU NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_EXISTE_SKU
    FROM SKU
    WHERE UPPER(TRIM(SKU_CODE)) = UPPER(TRIM(P_SKU_CODE))
       OR UPPER(TRIM(DESCRIPTION)) = UPPER(TRIM(P_DESCRIPTION));

    RETURN V_EXISTE_SKU;

END;
/
-- TRIM elimina espacios al inicio y al final de un texto,
-- permite comparaciones más precisas entre los datos.

-- Esta función valida que no exista previamente un SKU
-- con el mismo código o la misma descripción,
-- evitando el registro de productos duplicados.


CREATE OR REPLACE FUNCTION FN_EXISTE_MARCA(
    P_NAME_MARCA MARCA.NAME%TYPE
)
RETURN NUMBER
AS
    V_TOTAL NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_TOTAL
    FROM MARCA
    WHERE UPPER(TRIM(NAME)) = UPPER(TRIM(P_NAME_MARCA));

    RETURN V_TOTAL;

END;
/
--- Esta funcion valida que la marca exista para validarlo antes de registrar el SKU



-------PROCEDIMIENTOS---------
      ---CREAR SKU----
CREATE OR REPLACE PROCEDURE SP_CREAR_SKU(
    P_SKU_CODE SKU.SKU_CODE%TYPE,
    P_BRAND_ID SKU.BRAND_ID%TYPE,
    P_DESCRIPTION SKU.DESCRIPTION%TYPE,
    P_NET_CONTENT SKU.NET_CONTENT%TYPE,
    P_UOM SKU.UOM%TYPE,
    P_PRESENTATION SKU.PRESENTATION%TYPE,
    P_STATUS SKU.STATUS%TYPE
)
AS
BEGIN

    -- Llama a la funcion que Valida que el producto no exista
    IF FN_EXISTE_SKU(P_SKU_CODE, P_DESCRIPTION) > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20002,
            'El producto ya existe'
        );

    END IF;

    -- Llama a la funcion Valida que la marca exista
    IF FN_EXISTE_MARCA(P_BRAND_ID) = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20003,
            'La marca indicada no existe'
        );

    END IF;

    INSERT INTO SKU(
        SKU_CODE,
        BRAND_ID,
        DESCRIPTION,
        NET_CONTENT,
        UOM,
        PRESENTATION,
        STATUS
    )
    VALUES(
        P_SKU_CODE,
        P_BRAND_ID,
        P_DESCRIPTION,
        P_NET_CONTENT,
        P_UOM,
        P_PRESENTATION,
        P_STATUS
    );


END;
/

----Nota: RAISE_APPLICATION_ERROR se utiliza para mostrar mensajes de error personalizados y detener la ejecución del procedimiento
----cuando se detecta una condición no válida, por ejemplo, intentar registrar una categoría que ya existe.



---ACTUALIZAR---
CREATE OR REPLACE PROCEDURE SP_CONSULTAR_SKU(
    P_SKU_CODE SKU.SKU_CODE%TYPE,
    P_CURSOR OUT SYS_REFCURSOR
)
AS
BEGIN

    OPEN P_CURSOR FOR

    SELECT
        SKU_CODE,
        DESCRIPTION,
        NET_CONTENT,
        UOM,
        PRESENTATION,
        STATUS
    FROM SKU
    WHERE SKU_CODE = P_SKU_CODE;

END;
/

---  ACTUALIZAR----
CREATE OR REPLACE PROCEDURE SP_ACTUALIZAR_SKU(
    P_PRODUCT_ID SKU.PRODUCT_ID%TYPE,
    P_SKU_CODE SKU.SKU_CODE%TYPE,
    P_BRAND_ID SKU.BRAND_ID%TYPE,
    P_DESCRIPTION SKU.DESCRIPTION%TYPE,
    P_NET_CONTENT SKU.NET_CONTENT%TYPE,
    P_UOM SKU.UOM%TYPE,
    P_PRESENTATION SKU.PRESENTATION%TYPE,
    P_STATUS SKU.STATUS%TYPE
)
AS
BEGIN

    UPDATE SKU
       SET SKU_CODE = P_SKU_CODE,
           BRAND_ID = P_BRAND_ID,
           DESCRIPTION = P_DESCRIPTION,
           NET_CONTENT = P_NET_CONTENT,
           UOM = P_UOM,
           PRESENTATION = P_PRESENTATION,
           STATUS = P_STATUS
     WHERE PRODUCT_ID = P_PRODUCT_ID;


END;
/

----ELIMINAR SKU-- BORRADO LÓGICO---

CREATE OR REPLACE PROCEDURE SP_ELIMINAR_SKU(
    P_PRODUCT_ID SKU.PRODUCT_ID%TYPE
)
AS
BEGIN

    UPDATE SKU
       SET STATUS='INACTIVE'
     WHERE PRODUCT_ID=P_PRODUCT_ID;

    COMMIT;

END;
/


------ VISTAS -----


CREATE OR REPLACE VIEW VW_SKU_ACTIVOS AS
SELECT
    SKU_CODE,
    DESCRIPTION,
    NET_CONTENT,
    UOM,
    PRESENTATION
FROM SKU
WHERE STATUS = 'ACTIVE';



CREATE OR REPLACE VIEW VW_SKU_MARCA AS
SELECT
    S.SKU_CODE,
    S.DESCRIPTION,
    M.NAME AS MARCA,
    S.NET_CONTENT,
    S.UOM,
    S.STATUS
FROM SKU S
INNER JOIN MARCA M
    ON S.BRAND_ID = M.BRAND_ID;



