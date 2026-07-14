/* ============================================================
   PROYECTO: RetailMan
   MODULO   : Gestion de Marcas y Fabricantes
   REQ 5    : Gestionar Marcas   (Crear, Modificar, Asociar a Fabricante)
   REQ 6    : Gestionar Fabricantes (Registrar, Sin duplicados)
   Autor    : Katherine Araya
   Motor    : Oracle PL/SQL
============================================================ */

/* Constraint de respaldo para reforzar "no duplicados" en Fabricante
   (a nivel de base de datos, ademas de la validacion en el procedimiento) */
   
ALTER TABLE FABRICANTE
ADD CONSTRAINT FABRICANTE_NAME UNIQUE (NAME);

/*Función para verificar si ya existe un FABRICANTE con el mismo nombre*/

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

/*Función para verificar si el FABRICANTE existe (validar la FK antes de asociarlo a una marca) */

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

/*Función para verificar si ya existe una MARCA con el mismo nombre para el mismo FABRICANTE*/

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

/*Función para verificar si un FABRICANTE tiene MARCAS asociadas*/

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

/*Procedimiento para CREAR FABRICANTES (añadir FABRICANTES a la bd) */

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

/*Procedimiento para LEER FABRICANTES (REF CURSOR)*/

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

/*Procedimiento para ACTUALIZAR FABRICANTES*/

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

/*Procedimiento para ELIMINAR FABRICANTES (No se borrará si el FABRICANTE tiene marcas asociadas)*/

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

/*Procedimiento para CREAR MARCAS (añadir MARCAS a la bd)*/

CREATE OR REPLACE PROCEDURE crear_marca (
    p_manufacturer_id IN marca.manufacturer_id%TYPE,
    p_name            IN marca.name%TYPE,
    p_status          IN marca.status%TYPE DEFAULT 'ACTIVO',
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

/*Procedimiento para LEER MARCAS (REF CURSOR)*/

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

/*Procedimiento para ACTUALIZAR MARCAS*/

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

/*Procedimiento para ELIMINAR MARCAS*/

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

--------------------------------------------------------------------------------

DECLARE
    v_nuevo_id fabricante.manufacturer_id%TYPE;
BEGIN
    crear_fabricante(
        p_name         => 'Nestlé',
        p_country_code => 'CH',
        p_new_id       => v_nuevo_id
    );
    dbms_output.put_line('Fabricante creado con ID: ' || v_nuevo_id);
END;
/

--------------------------------------------------------------------------------

DECLARE
    v_nueva_marca marca.brand_id%TYPE;
BEGIN
    crear_marca(
        p_manufacturer_id => 1,          -- el ID del fabricante ya existente
        p_name            => 'KitKat',
        p_status          => 'ACTIVE',
        p_new_id          => v_nueva_marca
    );

    dbms_output.put_line('Marca creada con ID: ' || v_nueva_marca);
END;
/