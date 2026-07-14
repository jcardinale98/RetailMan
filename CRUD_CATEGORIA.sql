---- Procedimientos, Funciones y Vistas asociadas a la Tabla Categoria-----


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

    COMMIT;

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


----- FUNCIONES -----


CREATE OR REPLACE FUNCTION FN_EXISTE_CATEGORIA(
    P_CODE CATEGORIA.CODE%TYPE,
    P_NAME CATEGORIA.NAME%TYPE
)
RETURN NUMBER
AS
    V_TOTAL NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_TOTAL
    FROM CATEGORIA
    WHERE UPPER(CODE) = UPPER(P_CODE)
       OR UPPER(NAME) = UPPER(P_NAME);

    RETURN V_TOTAL;

END;
/
--Esta funcion Valida que no se repita el código o el nombre de una categoría
