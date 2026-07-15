SET SERVEROUTPUT ON;

--------------------------------------------------------------------------------
-- RETAILMAN - OBJETOS REEJECUTABLES
-- No crea tablas, no agrega restricciones y no ejecuta datos de prueba.
-- Requiere que las tablas base ya existan.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fabricante_duplicado (
    f_name       IN fabricante.name%TYPE,
    f_excluir_id IN fabricante.manufacturer_id%TYPE DEFAULT NULL
) RETURN NUMBER IS
    v_count NUMBER;  --Variable

BEGIN
    SELECT
        COUNT(*)
    INTO v_count
    FROM
        fabricante
    WHERE
            upper(trim(name)) = upper(trim(f_name))
        AND ( f_excluir_id IS NULL
              OR manufacturer_id <> f_excluir_id );

    RETURN v_count; -- 0 = no hay duplicado, >0 = ya existe

END fabricante_duplicado;
/


CREATE OR REPLACE FUNCTION fabricante_existe (
    f_manufacturer_id IN fabricante.manufacturer_id%TYPE
) RETURN NUMBER IS
    v_count NUMBER;  --Variable

BEGIN
    SELECT
        COUNT(*)
    INTO v_count
    FROM
        fabricante
    WHERE
        manufacturer_id = f_manufacturer_id;

    RETURN v_count; -- 0 = no existe, 1 = existe

END fabricante_existe;
/


CREATE OR REPLACE FUNCTION marca_duplicada (
    m_manufacturer_id IN marca.manufacturer_id%TYPE,
    m_name            IN marca.name%TYPE,
    m_excluir_id      IN marca.brand_id%TYPE DEFAULT NULL
) RETURN NUMBER IS
    v_count NUMBER;  --Variable

BEGIN
    SELECT
        COUNT(*)
    INTO v_count
    FROM
        marca
    WHERE
            manufacturer_id = m_manufacturer_id
        AND upper(trim(name)) = upper(trim(m_name))
        AND ( m_excluir_id IS NULL
              OR brand_id <> m_excluir_id );

    RETURN v_count; -- 0 = no hay duplicado, >0 = ya existe

END marca_duplicada;
/


CREATE OR REPLACE FUNCTION fabricante_tiene_marcas (
    f_manufacturer_id IN fabricante.manufacturer_id%TYPE
) RETURN NUMBER IS
    v_count NUMBER;  --Variable

BEGIN
    SELECT
        COUNT(*)
    INTO v_count
    FROM
        marca
    WHERE
        manufacturer_id = f_manufacturer_id;

    RETURN v_count; -- 0 = no existe, 1 = existe

END fabricante_tiene_marcas;
/


CREATE OR REPLACE PROCEDURE crear_fabricante (
    p_name         IN fabricante.name%TYPE,
    p_country_code IN fabricante.country_code%TYPE,
    p_new_id       OUT fabricante.manufacturer_id%TYPE
) IS
BEGIN
    IF p_name IS NULL
       OR TRIM(p_name) IS NULL THEN
        raise_application_error(-20001, 'El nombre del fabricante es obligatorio.');
    END IF;

    IF fabricante_duplicado(p_name) > 0 THEN
        raise_application_error(-20002, 'Ya existe un fabricante registrado con ese nombre.');
    END IF;

    INSERT INTO fabricante (
        name,
        country_code
    ) VALUES ( TRIM(p_name),
               p_country_code ) RETURNING manufacturer_id INTO p_new_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END crear_fabricante;
/


CREATE OR REPLACE PROCEDURE leer_fabricante (
    p_manufacturer_id IN fabricante.manufacturer_id%TYPE DEFAULT NULL,
    p_cursor          OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR SELECT
                                            manufacturer_id,
                                            name,
                                            country_code
                                        FROM
                                            fabricante
                      WHERE
                          ( p_manufacturer_id IS NULL
                            OR manufacturer_id = p_manufacturer_id )
                      ORDER BY
                          name;

END leer_fabricante;
/


CREATE OR REPLACE PROCEDURE actualizar_fabricante (
    p_manufacturer_id IN fabricante.manufacturer_id%TYPE,
    p_name            IN fabricante.name%TYPE,
    p_country_code    IN fabricante.country_code%TYPE
) IS
BEGIN
    IF fabricante_existe(p_manufacturer_id) = 0 THEN
        raise_application_error(-20003, 'El fabricante indicado no existe.');
    END IF;

    IF fabricante_duplicado(p_name, p_manufacturer_id) > 0 THEN
        raise_application_error(-20002, 'Ya existe otro fabricante con ese nombre.');
    END IF;

    UPDATE fabricante
    SET
        name = TRIM(p_name),
        country_code = p_country_code
    WHERE
        manufacturer_id = p_manufacturer_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END actualizar_fabricante;
/


CREATE OR REPLACE PROCEDURE eliminar_fabricante (
    p_manufacturer_id IN fabricante.manufacturer_id%TYPE
) IS
BEGIN
    IF fabricante_existe(p_manufacturer_id) = 0 THEN
        raise_application_error(-20003, 'El fabricante indicado no existe.');
    END IF;

    IF fabricante_tiene_marcas(p_manufacturer_id) > 0 THEN
        raise_application_error(-20004, 'No se puede eliminar: el fabricante tiene marcas asociadas.');
    END IF;

    DELETE FROM fabricante
    WHERE
        manufacturer_id = p_manufacturer_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END eliminar_fabricante;
/


CREATE OR REPLACE PROCEDURE crear_marca (
    p_manufacturer_id IN marca.manufacturer_id%TYPE,
    p_name            IN marca.name%TYPE,
    p_status          IN marca.status%TYPE DEFAULT 'ACTIVE',
    p_new_id          OUT marca.brand_id%TYPE
) IS
BEGIN
    IF p_name IS NULL
       OR TRIM(p_name) IS NULL THEN
        raise_application_error(-20005, 'El nombre de la marca es obligatorio.');
    END IF;

    -- R5: la marca debe poderse asociar a un fabricante -> se valida que exista
    IF fabricante_existe(p_manufacturer_id) = 0 THEN
        raise_application_error(-20006, 'El fabricante asociado no existe.');
    END IF;

    IF marca_duplicada(p_manufacturer_id, p_name) > 0 THEN
        raise_application_error(-20007, 'Ya existe una marca con ese nombre para el fabricante indicado.');
    END IF;

    IF p_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        raise_application_error(-20009, 'El estado debe ser ACTIVE o INACTIVE.');
    END IF;

    INSERT INTO marca (
        manufacturer_id,
        name,
        status
    ) VALUES ( p_manufacturer_id,
               TRIM(p_name),
               p_status ) RETURNING brand_id INTO p_new_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END crear_marca;
/


CREATE OR REPLACE PROCEDURE leer_marca (
    p_brand_id IN marca.brand_id%TYPE DEFAULT NULL,
    p_cursor   OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR SELECT
                                            m.brand_id,
                                            m.name,
                                            m.status,
                                            m.manufacturer_id,
                                            f.name AS fabricante_nombre
                                        FROM
                                                 marca m
                                            JOIN fabricante f ON f.manufacturer_id = m.manufacturer_id
                      WHERE
                          ( p_brand_id IS NULL
                            OR m.brand_id = p_brand_id )
                      ORDER BY
                          m.name;

END leer_marca;
/


CREATE OR REPLACE PROCEDURE actualizar_marca (
    p_brand_id        IN marca.brand_id%TYPE,
    p_manufacturer_id IN marca.manufacturer_id%TYPE,
    p_name            IN marca.name%TYPE,
    p_status          IN marca.status%TYPE
) IS
    v_existe NUMBER;
BEGIN
    SELECT
        COUNT(*)
    INTO v_existe
    FROM
        marca
    WHERE
        brand_id = p_brand_id;

    IF v_existe = 0 THEN
        raise_application_error(-20008, 'La marca indicada no existe.');
    END IF;
    IF fabricante_existe(p_manufacturer_id) = 0 THEN
        raise_application_error(-20006, 'El fabricante asociado no existe.');
    END IF;

    IF marca_duplicada(p_manufacturer_id, p_name, p_brand_id) > 0 THEN
        raise_application_error(-20007, 'Ya existe otra marca con ese nombre para el fabricante indicado.');
    END IF;

    IF p_status NOT IN ('ACTIVE', 'INACTIVE') THEN
        raise_application_error(-20009, 'El estado debe ser ACTIVE o INACTIVE.');
    END IF;

    UPDATE marca
    SET
        manufacturer_id = p_manufacturer_id,
        name = TRIM(p_name),
        status = p_status
    WHERE
        brand_id = p_brand_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END actualizar_marca;
/


CREATE OR REPLACE PROCEDURE eliminar_marca (
    p_brand_id IN marca.brand_id%TYPE
) IS
    v_existe NUMBER;
BEGIN
    SELECT
        COUNT(*)
    INTO v_existe
    FROM
        marca
    WHERE
        brand_id = p_brand_id;

    IF v_existe = 0 THEN
        raise_application_error(-20008, 'La marca indicada no existe.');
    END IF;
    DELETE FROM marca
    WHERE
        brand_id = p_brand_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END eliminar_marca;
/


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


CREATE OR REPLACE TRIGGER TRG_PUNTO_VENTA
BEFORE INSERT ON PUNTO_VENTA
FOR EACH ROW
BEGIN

    IF :NEW.status IS NULL THEN

        :NEW.status := 'ACTIVE';

    END IF;

END;
/


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


CREATE OR REPLACE FUNCTION FN_EXISTE_MARCA(
    P_BRAND_ID MARCA.BRAND_ID%TYPE
)
RETURN NUMBER
AS
    V_TOTAL NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_TOTAL
    FROM MARCA
    WHERE BRAND_ID = P_BRAND_ID;

    RETURN V_TOTAL;

END;
/


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

    IF P_SKU_CODE IS NULL OR TRIM(P_SKU_CODE) IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Debe indicar el codigo del producto'
        );
    END IF;

    IF P_DESCRIPTION IS NULL OR TRIM(P_DESCRIPTION) IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'Debe indicar la descripcion del producto'
        );
    END IF;

    IF P_STATUS NOT IN ('ACTIVE', 'INACTIVE') THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'El estado debe ser ACTIVE o INACTIVE'
        );
    END IF;

    -- Llama a la funcion que valida que el producto no exista
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

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END;
/


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


    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20013,
            'El producto indicado no existe'
        );
    END IF;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END;
/


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


CREATE OR REPLACE FUNCTION FN_EXISTE_PRODUCTO_CATEGORIA(
    P_PRODUCT_ID PRODUCTO_CATEGORIA.PRODUCT_ID%TYPE,
    P_CATEGORY_ID PRODUCTO_CATEGORIA.CATEGORY_ID%TYPE
)
RETURN NUMBER
AS
    V_TOTAL NUMBER;
BEGIN

    SELECT COUNT(*)
    INTO V_TOTAL
    FROM PRODUCTO_CATEGORIA
    WHERE PRODUCT_ID = P_PRODUCT_ID
    AND CATEGORY_ID = P_CATEGORY_ID;

    RETURN V_TOTAL;

END;
/


CREATE OR REPLACE PROCEDURE SP_ASIGNAR_PRODUCTO_CATEGORIA(
    P_PRODUCT_ID PRODUCTO_CATEGORIA.PRODUCT_ID%TYPE,
    P_CATEGORY_ID PRODUCTO_CATEGORIA.CATEGORY_ID%TYPE
)
AS
BEGIN

    IF FN_EXISTE_PRODUCTO_CATEGORIA(
        P_PRODUCT_ID,
        P_CATEGORY_ID
    ) > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20004,
            'La asociación ya existe'
        );

    END IF;

    INSERT INTO PRODUCTO_CATEGORIA(
        PRODUCT_ID,
        CATEGORY_ID
    )
    VALUES(
        P_PRODUCT_ID,
        P_CATEGORY_ID
    );

    COMMIT;

END;
/


CREATE OR REPLACE PROCEDURE SP_CONSULTAR_PRODUCTO_CATEGORIA(
    P_CURSOR OUT SYS_REFCURSOR
)
AS
BEGIN

    OPEN P_CURSOR FOR

    SELECT
        S.SKU_CODE,
        S.DESCRIPTION,
        C.CODE AS CODIGO_CATEGORIA,
        C.NAME AS CATEGORIA
    FROM PRODUCTO_CATEGORIA PC
    INNER JOIN SKU S
        ON PC.PRODUCT_ID = S.PRODUCT_ID
    INNER JOIN CATEGORIA C
        ON PC.CATEGORY_ID = C.CATEGORY_ID;

END;
/


CREATE OR REPLACE PROCEDURE SP_ELIMINAR_PRODUCTO_CATEGORIA(
    P_PRODUCT_ID PRODUCTO_CATEGORIA.PRODUCT_ID%TYPE,
    P_CATEGORY_ID PRODUCTO_CATEGORIA.CATEGORY_ID%TYPE
)
AS
BEGIN

    DELETE FROM PRODUCTO_CATEGORIA
    WHERE PRODUCT_ID = P_PRODUCT_ID
    AND CATEGORY_ID = P_CATEGORY_ID;

    COMMIT;

END;
/


CREATE OR REPLACE VIEW VW_PRODUCTOS_CATEGORIAS
AS
SELECT
    S.SKU_CODE,
    S.DESCRIPTION,
    C.CODE AS CODIGO_CATEGORIA,
    C.NAME AS CATEGORIA
FROM PRODUCTO_CATEGORIA PC
INNER JOIN SKU S
    ON PC.PRODUCT_ID = S.PRODUCT_ID
INNER JOIN CATEGORIA C
    ON PC.CATEGORY_ID = C.CATEGORY_ID;


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

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END;
/


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

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END;
/


CREATE OR REPLACE PROCEDURE SP_ELIMINAR_CATEGORIA(
   P_CATEGORY_ID CATEGORIA.CATEGORY_ID%TYPE
)
AS
BEGIN

    UPDATE CATEGORIA
    SET STATUS = 'INACTIVE'
    WHERE CATEGORY_ID = P_CATEGORY_ID;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;

END;
/


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


CREATE OR REPLACE PROCEDURE registrar_retailer
(
    p_market_id IN RETAILER.market_id%TYPE,
    p_code      IN RETAILER.code%TYPE,
    p_name      IN RETAILER.name%TYPE
)
IS
    v_mercado_existe NUMBER;
    v_codigo_existe  NUMBER;
BEGIN
    IF p_market_id IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Debe indicar el mercado del retailer.'
        );
    END IF;

    IF p_code IS NULL OR TRIM(p_code) IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Debe indicar el codigo del retailer.'
        );
    END IF;

    IF p_name IS NULL OR TRIM(p_name) IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Debe indicar el nombre del retailer.'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_mercado_existe
    FROM MERCADO
    WHERE market_id = p_market_id;

    IF v_mercado_existe = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20004,
            'El mercado indicado no existe.'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_codigo_existe
    FROM RETAILER
    WHERE market_id = p_market_id
      AND UPPER(TRIM(code)) = UPPER(TRIM(p_code));

    IF v_codigo_existe > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'Ya existe un retailer con ese codigo en el mercado.'
        );
    END IF;

    INSERT INTO RETAILER
    (
        market_id,
        code,
        name,
        status
    )
    VALUES
    (
        p_market_id,
        TRIM(p_code),
        TRIM(p_name),
        'ACTIVE'
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Retailer registrado correctamente.'
    );

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


CREATE OR REPLACE PROCEDURE asociar_retailer_mercado
(
    p_retailer_id IN RETAILER.retailer_id%TYPE,
    p_market_id   IN MERCADO.market_id%TYPE
)
IS

    v_retailer_existe NUMBER;
    v_mercado_existe NUMBER;
    v_asociacion_existe NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_retailer_existe
    FROM RETAILER
    WHERE retailer_id = p_retailer_id;

    IF v_retailer_existe = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20003,
            'El retailer indicado no existe.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_mercado_existe
    FROM MERCADO
    WHERE market_id = p_market_id;

    IF v_mercado_existe = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20004,
            'El mercado indicado no existe.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_asociacion_existe
    FROM RETAILER_MERCADO
    WHERE retailer_id = p_retailer_id
    AND market_id = p_market_id;

    IF v_asociacion_existe > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20005,
            'El retailer ya se encuentra asociado con ese mercado.'
        );

    END IF;


    INSERT INTO RETAILER_MERCADO
    (
        retailer_id,
        market_id
    )
    VALUES
    (
        p_retailer_id,
        p_market_id
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Retailer asociado correctamente con el mercado.'
    );

END;
/


CREATE OR REPLACE PROCEDURE cambiar_estado_retailer
(
    p_retailer_id IN RETAILER.retailer_id%TYPE,
    p_status      IN RETAILER.status%TYPE
)
IS

    v_retailer_existe NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_retailer_existe
    FROM RETAILER
    WHERE retailer_id = p_retailer_id;

    IF v_retailer_existe = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20006,
            'El retailer indicado no existe.'
        );

    END IF;


    IF p_status <> 'ACTIVE'
       AND p_status <> 'INACTIVE' THEN

        RAISE_APPLICATION_ERROR(
            -20007,
            'El estado debe ser ACTIVE o INACTIVE.'
        );

    END IF;


    UPDATE RETAILER
    SET status = p_status
    WHERE retailer_id = p_retailer_id;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Estado del retailer actualizado correctamente.'
    );

END;
/


CREATE OR REPLACE PROCEDURE asociar_gtin_sku
(
    p_product_id IN SKU.product_id%TYPE,
    p_gtin       IN PRODUCTOS_GTIN.gtin%TYPE
)
IS

    v_sku_existe NUMBER;
    v_gtin_existe NUMBER;

BEGIN

    SELECT COUNT(*)
    INTO v_sku_existe
    FROM SKU
    WHERE product_id = p_product_id;

    IF v_sku_existe = 0 THEN

        RAISE_APPLICATION_ERROR(
            -20008,
            'El SKU no existe. Debe crear primero el producto para continuar.'
        );

    END IF;


    SELECT COUNT(*)
    INTO v_gtin_existe
    FROM PRODUCTOS_GTIN
    WHERE gtin = p_gtin;

    IF v_gtin_existe > 0 THEN

        RAISE_APPLICATION_ERROR(
            -20009,
            'El GTIN ya está asociado con otro producto SKU.'
        );

    END IF;


    INSERT INTO PRODUCTOS_GTIN
    (
        product_id,
        gtin
    )
    VALUES
    (
        p_product_id,
        p_gtin
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'GTIN asociado correctamente con el producto SKU.'
    );

END;
/
