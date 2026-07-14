---- Procedimientos, Funciones y Vistas asociadas a la Tabla Categoria-----

/* ============================================================
   PROYECTO: RetailMan
   MODULO   : Gestion CATEGORIAS
   REQ 3    : Administrar Categorías
   Autor    : Catalina Mora
   Motor    : Oracle PL/SQL
============================================================ */

----- FUNCIONES -----


--- VALIDACION DE QUE UNA CATEGORIA NO EXISTA----- 

CREATE OR REPLACE FUNCTION FN_EXISTE_CATEGORIA(
    P_CODE CATEGORIA.CODE%TYPE,
    P_NAME CATEGORIA.NAME%TYPE
)
RETURN NUMBER
AS
    V_EXISTE NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_EXISTE
    FROM CATEGORIA
    WHERE UPPER(CODE) = UPPER(P_CODE)
       OR UPPER(NAME) = UPPER(P_NAME);

    RETURN V_EXISTE;

END;
/
-- Esta función valida si ya existe una categoría
-- con el mismo código o nombre, para evitar
-- registros duplicados en la tabla CATEGORIA.


----- FUNCION QUE CUENTA CUANTAS SUBCATEGORIAS PERTENECEN A UNA CATEGORIA-----


CREATE OR REPLACE FUNCTION FN_TOTAL_SUBCATEGORIAS(
    P_CATEGORY_ID CATEGORIA.CATEGORY_ID%TYPE
)
RETURN NUMBER
AS
    V_TOTAL_SUBCATEGORIAS NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_TOTAL_SUBCATEGORIAS
    FROM CATEGORIA
    WHERE PARENT_ID = P_CATEGORY_ID;

    RETURN V_TOTAL_SUBCATEGORIAS;

END;
/

-- Esta función cuenta la cantidad de subcategorías
-- asociadas a una categoría padre.



----PROCEDIMIENTOS----

---- CREAR CATEGORIA---

CREATE OR REPLACE PROCEDURE SP_CREAR_CATEGORIA(
    P_CODE      CATEGORIA.CODE%TYPE,
    P_NAME      CATEGORIA.NAME%TYPE,
    P_LEVEL_NO  CATEGORIA.LEVEL_NO%TYPE,
    P_PARENT_ID CATEGORIA.PARENT_ID%TYPE,
    P_STATUS    CATEGORIA.STATUS%TYPE
)
AS
BEGIN

    IF FN_EXISTE_CATEGORIA(P_CODE, P_NAME) > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'La categoría ya existe por código o nombre'
        );
    END IF;

    INSERT INTO CATEGORIA(
        CODE,
        NAME,
        LEVEL_NO,
        PARENT_ID,
        STATUS
    )
    VALUES(
        P_CODE,
        P_NAME,
        P_LEVEL_NO,
        P_PARENT_ID,
        P_STATUS
    );


END;
/
----Nota: RAISE_APPLICATION_ERROR se utiliza para mostrar mensajes de error personalizados y detener la ejecución del procedimiento
----cuando se detecta una condición no válida, por ejemplo, intentar registrar una categoría que ya existe.


-----------------------------
---- CONSULTAR CATEGORIA ----

CREATE OR REPLACE PROCEDURE SP_CONSULTAR_CATEGORIA(
    P_CATEGORY_ID NUMBER,
    P_CURSOR OUT SYS_REFCURSOR
)
AS
BEGIN

    OPEN P_CURSOR FOR

    SELECT *
    FROM CATEGORIA
    WHERE CATEGORY_ID = P_CATEGORY_ID;

END;
/

-------------------------------
------ACTUALIZAR CATEGORIA-----

CREATE OR REPLACE PROCEDURE SP_ACTUALIZAR_CATEGORIA(
    P_CATEGORY_ID CATEGORIA.CATEGORY_ID%TYPE,
    P_CODE CATEGORIA.CODE%TYPE,
    P_NAME CATEGORIA.NAME%TYPE,
    P_LEVEL_NO CATEGORIA.LEVEL_NO%TYPE,
    P_PARENT_ID CATEGORIA.PARENT_ID%TYPE,
    P_STATUS CATEGORIA.STATUS%TYPE
)
AS
BEGIN

    UPDATE CATEGORIA
    SET
        CODE = P_CODE,
        NAME = P_NAME,
        LEVEL_NO = P_LEVEL_NO,
        PARENT_ID = P_PARENT_ID,
        STATUS = P_STATUS
    WHERE CATEGORY_ID = P_CATEGORY_ID;

END;
/

-----------------------------------
-----  ELIMINAR CATEGORIA----------
--Este sería un borrado lógico ---


CREATE OR REPLACE PROCEDURE SP_ELIMINAR_CATEGORIA(
   P_CATEGORY_ID CATEGORIA.CATEGORY_ID%TYPE
)
AS
BEGIN

    UPDATE CATEGORIA
    SET STATUS = 'INACTIVE'
    WHERE CATEGORY_ID = P_CATEGORY_ID;

END;
/

------- VISTAS ------


CREATE OR REPLACE VIEW VW_CATEGORIAS_ACTIVAS AS
SELECT
    CODE,
    NAME,
    LEVEL_NO,
    PARENT_ID,
    STATUS
FROM CATEGORIA
WHERE STATUS = 'ACTIVE';



CREATE OR REPLACE VIEW VW_JERARQUIA_CATEGORIAS AS
SELECT
    C1.CODE AS CODIGO_CATEGORIA,
    C1.NAME AS CATEGORIA,
    C2.NAME AS CATEGORIA_PADRE,
    C1.LEVEL_NO
FROM CATEGORIA C1
LEFT JOIN CATEGORIA C2
    ON C1.PARENT_ID = C2.CATEGORY_ID;



