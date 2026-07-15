
--------------------------------------------------------------------------------
-- HISTORIA DE USUARIO 8
-- GESTIONAR PUNTOS DE VENTA
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON;

--------------------------------------------------------------------------------
-- 2. PROCEDIMIENTO PARA REGISTRAR PUNTOS DE VENTA
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_REGISTRAR_PUNTO_VENTA
(
    p_retailer_id IN PUNTO_VENTA.retailer_id%TYPE,
    p_market_id   IN PUNTO_VENTA.market_id%TYPE,
    p_channel_id  IN PUNTO_VENTA.channel_id%TYPE,
    p_code        IN PUNTO_VENTA.code%TYPE,
    p_name        IN PUNTO_VENTA.name%TYPE,
    p_zone        IN PUNTO_VENTA.zone%TYPE,
    p_address     IN PUNTO_VENTA.address%TYPE,
    p_resultado   OUT NUMBER
)
IS

    v_retailer_mercado NUMBER;
    v_canal            NUMBER;
    v_codigo           NUMBER;

BEGIN

    p_resultado := 0;

    ---------------------------------------------------------------------------
    -- VALIDAR CAMPOS OBLIGATORIOS
    ---------------------------------------------------------------------------

    IF p_retailer_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20001,
            'Debe indicar el retailer del punto de venta.'
        );

    END IF;


    IF p_market_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20002,
            'Debe indicar el mercado del punto de venta.'
        );

    END IF;


    IF p_channel_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20003,
            'Debe indicar el canal del punto de venta.'
        );

    END IF;


    IF p_code IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20004,
            'Debe indicar el codigo del punto de venta.'
        );

    END IF;


    IF p_name IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20005,
            'Debe indicar el nombre del punto de venta.'
        );

    END IF;


    IF p_zone IS NULL OR p_address IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20006,
            'Debe indicar la ubicacion del punto de venta.'
        );

    END IF;

    ---------------------------------------------------------------------------
    -- INSERTAR PUNTO DE VENTA
    ---------------------------------------------------------------------------

    INSERT INTO PUNTO_VENTA
    (
        retailer_id,
        market_id,
        channel_id,
        code,
        name,
        zone,
        address,
        status
    )
    VALUES
    (
        p_retailer_id,
        p_market_id,
        p_channel_id,
        p_code,
        p_name,
        p_zone,
        p_address,
        'ACTIVE'
    );

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/

--------------------------------------------------------------------------------
-- 3. PROCEDIMIENTO PARA CONSULTAR PUNTOS DE VENTA
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_CONSULTAR_PUNTOS_VENTA
(
    p_resultado OUT SYS_REFCURSOR
)
IS

BEGIN

    OPEN p_resultado FOR

        SELECT
            pv.store_id,
            pv.code,
            pv.name,
            pv.zone,
            pv.address,
            r.name AS retailer,
            m.name AS mercado,
            c.name AS canal,
            pv.status
        FROM PUNTO_VENTA pv
        INNER JOIN RETAILER r
            ON pv.retailer_id = r.retailer_id
        INNER JOIN MERCADO m
            ON pv.market_id = m.market_id
        INNER JOIN CANAL c
            ON pv.channel_id = c.channel_id
        ORDER BY pv.store_id;

END;
/

--------------------------------------------------------------------------------
-- 4. PROCEDIMIENTO PARA ACTUALIZAR PUNTOS DE VENTA
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_ACTUALIZAR_PUNTO_VENTA
(
    p_store_id   IN PUNTO_VENTA.store_id%TYPE,
    p_channel_id IN PUNTO_VENTA.channel_id%TYPE,
    p_name       IN PUNTO_VENTA.name%TYPE,
    p_zone       IN PUNTO_VENTA.zone%TYPE,
    p_address    IN PUNTO_VENTA.address%TYPE,
    p_status     IN PUNTO_VENTA.status%TYPE,
    p_resultado  OUT NUMBER
)
IS

    v_punto_venta NUMBER;
    v_canal       NUMBER;

BEGIN

    p_resultado := 0;

    ---------------------------------------------------------------------------
    -- VALIDAR CAMPOS
    ---------------------------------------------------------------------------

    IF p_store_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20010,
            'Debe indicar el punto de venta.'
        );

    END IF;


    IF p_channel_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20011,
            'Debe indicar el canal.'
        );

    END IF;


    IF p_name IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20012,
            'Debe indicar el nombre del punto de venta.'
        );

    END IF;


    IF p_zone IS NULL OR p_address IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20013,
            'Debe indicar la ubicacion del punto de venta.'
        );

    END IF;


    IF p_status IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20014,
            'Debe indicar el estado del punto de venta.'
        );

    END IF;


    IF p_status <> 'ACTIVE'
       AND p_status <> 'INACTIVE' THEN

        RAISE_APPLICATION_ERROR(
            -20015,
            'El estado debe ser ACTIVE o INACTIVE.'
        );

    END IF;

    ---------------------------------------------------------------------------
    -- ACTUALIZAR
    ---------------------------------------------------------------------------

    UPDATE PUNTO_VENTA
    SET
        channel_id = p_channel_id,
        name       = p_name,
        zone       = p_zone,
        address    = p_address,
        status     = p_status
    WHERE store_id = p_store_id;

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/

--------------------------------------------------------------------------------
-- 5. PROCEDIMIENTO PARA ELIMINAR LOGICAMENTE
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_ELIMINAR_PUNTO_VENTA
(
    p_store_id  IN PUNTO_VENTA.store_id%TYPE,
    p_resultado OUT NUMBER
)
IS

    v_punto_venta NUMBER;

BEGIN

    p_resultado := 0;

    IF p_store_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20018,
            'Debe indicar el punto de venta.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_punto_venta
    FROM PUNTO_VENTA
    WHERE store_id = p_store_id;

    IF v_punto_venta = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20019,
            'El punto de venta indicado no existe.'
        );

    END IF;


    UPDATE PUNTO_VENTA
    SET status = 'INACTIVE'
    WHERE store_id = p_store_id;

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/

--------------------------------------------------------------------------------
-- 6. PROCEDIMIENTO CON CURSOR
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_MOSTRAR_PUNTOS_VENTA
IS

    CURSOR c_puntos IS

        SELECT
            store_id,
            code,
            name,
            zone,
            status
        FROM PUNTO_VENTA
        ORDER BY store_id;

BEGIN

    FOR p IN c_puntos LOOP

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || p.store_id ||
            ' | CODIGO: ' || p.code ||
            ' | NOMBRE: ' || p.name ||
            ' | ZONA: ' || p.zone ||
            ' | ESTADO: ' || p.status
        );

    END LOOP;

END;
/

--------------------------------------------------------------------------------
-- 7. FUNCION PARA VALIDAR RETAILER
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION FN_EXISTE_RETAILER
(
    p_retailer_id IN RETAILER.retailer_id%TYPE
)
RETURN NUMBER
IS

    v_cantidad NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_cantidad
    FROM RETAILER
    WHERE retailer_id = p_retailer_id;

    RETURN v_cantidad;

END;
/

--------------------------------------------------------------------------------
-- 8. VISTA DE PUNTOS DE VENTA
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW VW_PUNTOS_VENTA AS

SELECT
    pv.store_id,
    pv.code,
    pv.name,
    pv.zone,
    pv.address,
    r.name AS retailer,
    m.name AS mercado,
    c.name AS canal,
    pv.status
FROM PUNTO_VENTA pv
INNER JOIN RETAILER r
    ON pv.retailer_id = r.retailer_id
INNER JOIN MERCADO m
    ON pv.market_id = m.market_id
INNER JOIN CANAL c
    ON pv.channel_id = c.channel_id;

--------------------------------------------------------------------------------
-- 9. TRIGGER PARA ASIGNAR ESTADO
--------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_PUNTO_VENTA
BEFORE INSERT ON PUNTO_VENTA
FOR EACH ROW
BEGIN

    IF :NEW.status IS NULL THEN

        :NEW.status := 'ACTIVE';

    END IF;

END;
/

--------------------------------------------------------------------------------
-- 10. PRUEBA DE REGISTRO
-- EVITA REGISTRAR WM02 DOS VECES
--------------------------------------------------------------------------------

DECLARE

    v_retailer_id RETAILER.retailer_id%TYPE;
    v_market_id   MERCADO.market_id%TYPE;
    v_channel_id  CANAL.channel_id%TYPE;
    v_resultado   NUMBER;
    v_cantidad    NUMBER;

BEGIN

    SELECT retailer_id, market_id
    INTO v_retailer_id, v_market_id
    FROM RETAILER
    WHERE code = 'WMCR';

    SELECT channel_id
    INTO v_channel_id
    FROM CANAL
    WHERE code = 'MD';

    SELECT COUNT(*)
    INTO v_cantidad
    FROM PUNTO_VENTA
    WHERE retailer_id = v_retailer_id
      AND code = 'WM02';

    IF v_cantidad = 0 THEN

        PR_REGISTRAR_PUNTO_VENTA
        (
            v_retailer_id,
            v_market_id,
            v_channel_id,
            'WM02',
            'Walmart Curridabat',
            'Curridabat',
            'Centro de Curridabat',
            v_resultado
        );

        IF v_resultado = 1 THEN

            DBMS_OUTPUT.PUT_LINE(
                'El punto de venta fue registrado correctamente.'
            );

        ELSE

            DBMS_OUTPUT.PUT_LINE(
                'No se pudo registrar el punto de venta.'
            );

        END IF;

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'El punto de venta WM02 ya se encuentra registrado.'
        );

    END IF;

END;
/

--------------------------------------------------------------------------------
-- 11. PRUEBA DE CONSULTA
--------------------------------------------------------------------------------

DECLARE

    v_resultado SYS_REFCURSOR;

    v_store_id PUNTO_VENTA.store_id%TYPE;
    v_code     PUNTO_VENTA.code%TYPE;
    v_name     PUNTO_VENTA.name%TYPE;
    v_zone     PUNTO_VENTA.zone%TYPE;
    v_address  PUNTO_VENTA.address%TYPE;
    v_retailer RETAILER.name%TYPE;
    v_mercado  MERCADO.name%TYPE;
    v_canal    CANAL.name%TYPE;
    v_status   PUNTO_VENTA.status%TYPE;

BEGIN

    PR_CONSULTAR_PUNTOS_VENTA(v_resultado);

    LOOP

        FETCH v_resultado
        INTO
            v_store_id,
            v_code,
            v_name,
            v_zone,
            v_address,
            v_retailer,
            v_mercado,
            v_canal,
            v_status;

        EXIT WHEN v_resultado%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || v_store_id ||
            ' | CODIGO: ' || v_code ||
            ' | NOMBRE: ' || v_name ||
            ' | RETAILER: ' || v_retailer ||
            ' | MERCADO: ' || v_mercado ||
            ' | CANAL: ' || v_canal ||
            ' | ESTADO: ' || v_status
        );

    END LOOP;

    CLOSE v_resultado;

END;
/

--------------------------------------------------------------------------------
-- 12. PRUEBA DE ACTUALIZACION
--------------------------------------------------------------------------------

DECLARE

    v_store_id   PUNTO_VENTA.store_id%TYPE;
    v_channel_id CANAL.channel_id%TYPE;
    v_resultado  NUMBER;

BEGIN

    SELECT store_id
    INTO v_store_id
    FROM PUNTO_VENTA
    WHERE code = 'WM02';

    SELECT channel_id
    INTO v_channel_id
    FROM CANAL
    WHERE code = 'MD';

    PR_ACTUALIZAR_PUNTO_VENTA
    (
        v_store_id,
        v_channel_id,
        'Walmart Curridabat Centro',
        'Curridabat',
        'Centro comercial de Curridabat',
        'ACTIVE',
        v_resultado
    );

    IF v_resultado = 1 THEN

        DBMS_OUTPUT.PUT_LINE(
            'El punto de venta fue actualizado correctamente.'
        );

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'No se pudo actualizar el punto de venta.'
        );

    END IF;

END;
/

--------------------------------------------------------------------------------
-- 13. PRUEBA DEL PROCEDIMIENTO CON CURSOR
--------------------------------------------------------------------------------

BEGIN

    PR_MOSTRAR_PUNTOS_VENTA;

END;
/


--------------------------------------------------------------------------------
-- 14. PRUEBA DE ELIMINACION LOGICA
-- SE EJECUTA AL FINAL
--------------------------------------------------------------------------------

DECLARE

    v_store_id  PUNTO_VENTA.store_id%TYPE;
    v_resultado NUMBER;

BEGIN

    SELECT store_id
    INTO v_store_id
    FROM PUNTO_VENTA
    WHERE code = 'WM02';

    PR_ELIMINAR_PUNTO_VENTA
    (
        v_store_id,
        v_resultado
    );

    IF v_resultado = 1 THEN

        DBMS_OUTPUT.PUT_LINE(
            'El punto de venta fue desactivado correctamente.'
        );

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'No se pudo desactivar el punto de venta.'
        );

    END IF;

END;
/




---------------------------------Historia de usuario 9-------------------------------

--------------------------------------------------------------------------------
-- HISTORIA DE USUARIO 9
-- GESTIONAR FORMATOS COMERCIALES
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. PROCEDIMIENTO PARA REGISTRAR FORMATOS
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_REGISTRAR_FORMATO
(
    p_code      IN FORMATO.code%TYPE,
    p_name      IN FORMATO.name%TYPE,
    p_resultado OUT NUMBER
)
IS

    v_codigo NUMBER;
    v_nombre NUMBER;

BEGIN

    p_resultado := 0;

    ---------------------------------------------------------------------------
    -- VALIDAR CAMPOS OBLIGATORIOS
    ---------------------------------------------------------------------------

    IF p_code IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20030,
            'Debe indicar el codigo del formato comercial.'
        );

    END IF;


    IF p_name IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20031,
            'Debe indicar el nombre del formato comercial.'
        );

    END IF;


    ---------------------------------------------------------------------------
    -- REGISTRAR FORMATO
    ---------------------------------------------------------------------------

    INSERT INTO FORMATO
    (
        code,
        name
    )
    VALUES
    (
        p_code,
        p_name
    );

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/

--Probar el registro:
SET SERVEROUTPUT ON;

DECLARE

    v_resultado NUMBER;
    v_cantidad  NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_cantidad
    FROM FORMATO
    WHERE code = 'CL';

    IF v_cantidad = 0 THEN

        PR_REGISTRAR_FORMATO
        (
            'CL',
            'Club de compras',
            v_resultado
        );

        IF v_resultado = 1 THEN

            DBMS_OUTPUT.PUT_LINE(
                'El formato comercial fue registrado correctamente.'
            );

        ELSE

            DBMS_OUTPUT.PUT_LINE(
                'No se pudo registrar el formato comercial.'
            );

        END IF;

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'El formato comercial CL ya se encuentra registrado.'
        );

    END IF;

END;
/

-----------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 2. PROCEDIMIENTO PARA ASOCIAR FORMATO CON RETAILER
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_ASOCIAR_FORMATO_RETAILER
(
    p_retailer_id IN RETAILER_FORMATO.retailer_id%TYPE,
    p_format_id   IN RETAILER_FORMATO.format_id%TYPE,
    p_name        IN RETAILER_FORMATO.name%TYPE,
    p_resultado   OUT NUMBER
)
IS

    v_retailer   NUMBER;
    v_formato    NUMBER;
    v_asociacion NUMBER;

BEGIN

    p_resultado := 0;

    ---------------------------------------------------------------------------
    -- VALIDAR CAMPOS OBLIGATORIOS
    ---------------------------------------------------------------------------

    IF p_retailer_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20034,
            'Debe indicar el retailer.'
        );

    END IF;


    IF p_format_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20035,
            'Debe indicar el formato comercial.'
        );

    END IF;


    IF p_name IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20036,
            'Debe indicar el nombre comercial de la asociacion.'
        );

    END IF;

    ---------------------------------------------------------------------------
    -- REGISTRAR ASOCIACION
    ---------------------------------------------------------------------------

    INSERT INTO RETAILER_FORMATO
    (
        retailer_id,
        format_id,
        name,
        status
    )
    VALUES
    (
        p_retailer_id,
        p_format_id,
        p_name,
        'ACTIVE'
    );

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/


--Probar la asociación sin usar IDs manuales:
SET SERVEROUTPUT ON;

DECLARE

    v_retailer_id RETAILER.retailer_id%TYPE;
    v_format_id   FORMATO.format_id%TYPE;
    v_resultado   NUMBER;
    v_cantidad    NUMBER;

BEGIN

    SELECT retailer_id
    INTO v_retailer_id
    FROM RETAILER
    WHERE code = 'PRC';

    SELECT format_id
    INTO v_format_id
    FROM FORMATO
    WHERE code = 'CL';

    SELECT COUNT(*)
    INTO v_cantidad
    FROM RETAILER_FORMATO
    WHERE retailer_id = v_retailer_id
      AND format_id = v_format_id;

    IF v_cantidad = 0 THEN

        PR_ASOCIAR_FORMATO_RETAILER
        (
            v_retailer_id,
            v_format_id,
            'PriceSmart Club de compras',
            v_resultado
        );

        IF v_resultado = 1 THEN

            DBMS_OUTPUT.PUT_LINE(
                'El formato fue asociado correctamente con el retailer.'
            );

        ELSE

            DBMS_OUTPUT.PUT_LINE(
                'No se pudo asociar el formato con el retailer.'
            );

        END IF;

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'El formato ya se encuentra asociado con el retailer.'
        );

    END IF;

END;
/


------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 3. PROCEDIMIENTO PARA CONSULTAR FORMATOS
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_CONSULTAR_FORMATOS
(
    p_resultado OUT SYS_REFCURSOR
)
IS

BEGIN

    OPEN p_resultado FOR

        SELECT
            format_id,
            code,
            name
        FROM FORMATO
        ORDER BY format_id;

END;
/

--Probar la consulta:
SET SERVEROUTPUT ON;

DECLARE

    v_resultado SYS_REFCURSOR;

    v_format_id FORMATO.format_id%TYPE;
    v_code      FORMATO.code%TYPE;
    v_name      FORMATO.name%TYPE;

BEGIN

    PR_CONSULTAR_FORMATOS(v_resultado);

    LOOP

        FETCH v_resultado
        INTO
            v_format_id,
            v_code,
            v_name;

        EXIT WHEN v_resultado%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || v_format_id ||
            ' | CODIGO: ' || v_code ||
            ' | NOMBRE: ' || v_name
        );

    END LOOP;

    CLOSE v_resultado;

END;
/
-----------------------------------------

--------------------------------------------------------------------------------
-- 4. PROCEDIMIENTO PARA ACTUALIZAR FORMATO
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_ACTUALIZAR_FORMATO
(
    p_format_id IN FORMATO.format_id%TYPE,
    p_code      IN FORMATO.code%TYPE,
    p_name      IN FORMATO.name%TYPE,
    p_resultado OUT NUMBER
)
IS

    v_formato NUMBER;
    v_codigo  NUMBER;
    v_nombre  NUMBER;

BEGIN

    p_resultado := 0;

    IF p_format_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20040,
            'Debe indicar el formato comercial.'
        );

    END IF;


    IF p_code IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20041,
            'Debe indicar el codigo del formato comercial.'
        );

    END IF;


    IF p_name IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20042,
            'Debe indicar el nombre del formato comercial.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_formato
    FROM FORMATO
    WHERE format_id = p_format_id;

    IF v_formato = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20043,
            'El formato comercial indicado no existe.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_codigo
    FROM FORMATO
    WHERE UPPER(code) = UPPER(p_code)
      AND format_id <> p_format_id;

    IF v_codigo > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20044,
            'Ya existe otro formato comercial con ese codigo.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_nombre
    FROM FORMATO
    WHERE UPPER(name) = UPPER(p_name)
      AND format_id <> p_format_id;

    IF v_nombre > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20045,
            'Ya existe otro formato comercial con ese nombre.'
        );

    END IF;


    UPDATE FORMATO
    SET
        code = p_code,
        name = p_name
    WHERE format_id = p_format_id;

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/

--Probar la actualización:
SET SERVEROUTPUT ON;

DECLARE

    v_format_id FORMATO.format_id%TYPE;
    v_resultado NUMBER;

BEGIN

    SELECT format_id
    INTO v_format_id
    FROM FORMATO
    WHERE code = 'CL';

    PR_ACTUALIZAR_FORMATO
    (
        v_format_id,
        'CL',
        'Club de Compras',
        v_resultado
    );

    IF v_resultado = 1 THEN

        DBMS_OUTPUT.PUT_LINE(
            'El formato comercial fue actualizado correctamente.'
        );

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'No se pudo actualizar el formato comercial.'
        );

    END IF;

END;
/
-------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 5. PROCEDIMIENTO PARA ELIMINAR FORMATO
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_ELIMINAR_FORMATO
(
    p_format_id IN FORMATO.format_id%TYPE,
    p_resultado OUT NUMBER
)
IS

    v_formato     NUMBER;
    v_asociaciones NUMBER;

BEGIN

    p_resultado := 0;

    IF p_format_id IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20046,
            'Debe indicar el formato comercial.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_formato
    FROM FORMATO
    WHERE format_id = p_format_id;

    IF v_formato = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20047,
            'El formato comercial indicado no existe.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_asociaciones
    FROM RETAILER_FORMATO
    WHERE format_id = p_format_id;

    IF v_asociaciones > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20048,
            'No se puede eliminar el formato porque esta asociado con un retailer.'
        );

    END IF;


    DELETE FROM FORMATO
    WHERE format_id = p_format_id;

    IF SQL%FOUND THEN

        p_resultado := 1;

    ELSE

        p_resultado := 0;

    END IF;

    COMMIT;

EXCEPTION

    WHEN OTHERS THEN

        p_resultado := 0;
        RAISE;

END;
/


--Crea primero un formato temporal:

SET SERVEROUTPUT ON;

DECLARE

    v_resultado NUMBER;
    v_cantidad  NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_cantidad
    FROM FORMATO
    WHERE code = 'TMP';

    IF v_cantidad = 0 THEN

        PR_REGISTRAR_FORMATO
        (
            'TMP',
            'Formato Temporal',
            v_resultado
        );

    END IF;

END;
/
-------------------
SET SERVEROUTPUT ON;

DECLARE

    v_format_id FORMATO.format_id%TYPE;
    v_resultado NUMBER;

BEGIN

    SELECT format_id
    INTO v_format_id
    FROM FORMATO
    WHERE code = 'TMP';

    PR_ELIMINAR_FORMATO
    (
        v_format_id,
        v_resultado
    );

    IF v_resultado = 1 THEN

        DBMS_OUTPUT.PUT_LINE(
            'El formato comercial fue eliminado correctamente.'
        );

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'No se pudo eliminar el formato comercial.'
        );

    END IF;

END;
/


------------------------------------------------------------

--Consultar asociaciones entre retailers y formatos

--------------------------------------------------------------------------------
-- 6. PROCEDIMIENTO PARA CONSULTAR ASOCIACIONES
--------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE PR_CONSULTAR_RETAILER_FORMATO
(
    p_resultado OUT SYS_REFCURSOR
)
IS

BEGIN

    OPEN p_resultado FOR

        SELECT
            rf.retailer_format_id,
            r.name AS retailer,
            f.code AS codigo_formato,
            f.name AS formato,
            rf.name AS nombre_comercial,
            rf.status
        FROM RETAILER_FORMATO rf
        INNER JOIN RETAILER r
            ON rf.retailer_id = r.retailer_id
        INNER JOIN FORMATO f
            ON rf.format_id = f.format_id
        ORDER BY rf.retailer_format_id;

END;
/

--Probar asociaciones:+

SET SERVEROUTPUT ON;

DECLARE

    v_resultado SYS_REFCURSOR;

    v_id               RETAILER_FORMATO.retailer_format_id%TYPE;
    v_retailer         RETAILER.name%TYPE;
    v_codigo_formato   FORMATO.code%TYPE;
    v_formato          FORMATO.name%TYPE;
    v_nombre_comercial RETAILER_FORMATO.name%TYPE;
    v_status           RETAILER_FORMATO.status%TYPE;

BEGIN

    PR_CONSULTAR_RETAILER_FORMATO(v_resultado);

    LOOP

        FETCH v_resultado
        INTO
            v_id,
            v_retailer,
            v_codigo_formato,
            v_formato,
            v_nombre_comercial,
            v_status;

        EXIT WHEN v_resultado%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || v_id ||
            ' | RETAILER: ' || v_retailer ||
            ' | FORMATO: ' || v_formato ||
            ' | NOMBRE COMERCIAL: ' || v_nombre_comercial ||
            ' | ESTADO: ' || v_status
        );

    END LOOP;

    CLOSE v_resultado;

END;
/
