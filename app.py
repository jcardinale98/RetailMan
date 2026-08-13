from datetime import datetime
import os
import oracledb
from flask import Flask, abort, flash, redirect, render_template, request, url_for
from dotenv import load_dotenv
from db import execute, fetch_all, fetch_one, get_connection, test_connection

load_dotenv()
app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "retailman-local")


def oracle_message(error):
    if isinstance(error, oracledb.Error) and error.args:
        obj = error.args[0]
        return getattr(obj, "message", str(obj)).strip()
    return str(error)


def n(value, kind="text"):
    value = value.strip() if isinstance(value, str) else value
    if value in (None, ""):
        return None
    if kind == "int":
        return int(value)
    if kind == "float":
        return float(value)
    return value


def callproc(name, args):
    with get_connection() as con:
        with con.cursor() as cur:
            cur.callproc(name, args)
        con.commit()


def callproc_out_number(name, in_args):
    with get_connection() as con:
        with con.cursor() as cur:
            out_value = cur.var(oracledb.NUMBER)
            cur.callproc(name, [*in_args, out_value])
            result = out_value.getvalue()
        con.commit()
    return result


def validate_category(name, level_no, parent_id, category_id=None):
    if not name:
        raise ValueError("Debe indicar el nombre de la categoría.")
    if level_no is None or level_no < 1:
        raise ValueError("El nivel jerárquico debe ser 1 o mayor.")

    duplicate = fetch_one(
        """
        SELECT COUNT(*) total
        FROM CATEGORIA
        WHERE UPPER(TRIM(name)) = UPPER(TRIM(:name))
          AND (:id IS NULL OR category_id <> :id)
        """,
        {"name": name, "id": category_id},
    )["total"]
    if duplicate > 0:
        raise ValueError("La categoría ya existe.")

    if parent_id is None:
        if level_no != 1:
            raise ValueError("Las categorías sin padre deben ser nivel 1.")
        return

    if category_id is not None and parent_id == category_id:
        raise ValueError("Una categoría no puede ser su propia categoría padre.")

    parent = fetch_one(
        "SELECT category_id, name, level_no, status FROM CATEGORIA WHERE category_id=:id",
        {"id": parent_id},
    )
    if not parent:
        raise ValueError("La categoría padre indicada no existe.")
    if parent["status"] != "ACTIVE":
        raise ValueError("La categoría padre debe estar activa.")
    if level_no != parent["level_no"] + 1:
        raise ValueError(
            f"Nivel jerárquico inválido. '{parent['name']}' es nivel {parent['level_no']}, "
            f"por lo que la subcategoría debe ser nivel {parent['level_no'] + 1}."
        )

    # Evita ciclos al editar: el padre nuevo no puede ser descendiente del registro actual.
    if category_id is not None:
        cycle = fetch_one(
            """
            SELECT COUNT(*) total
            FROM (
                SELECT category_id
                FROM CATEGORIA
                START WITH category_id = :parent_id
                CONNECT BY NOCYCLE PRIOR parent_id = category_id
            )
            WHERE category_id = :category_id
            """,
            {"parent_id": parent_id, "category_id": category_id},
        )
        if cycle and cycle["total"] > 0:
            raise ValueError("La categoría padre seleccionada generaría una relación circular.")


def validate_sku_duplicate(brand_id, description, net_content, uom, presentation, product_id=None):
    row = fetch_one(
        """
        SELECT COUNT(*) total
        FROM SKU
        WHERE NVL(brand_id,-1) = NVL(:brand_id,-1)
          AND UPPER(TRIM(description)) = UPPER(TRIM(:description))
          AND NVL(net_content,-1) = NVL(:net_content,-1)
          AND UPPER(TRIM(NVL(uom,' '))) = UPPER(TRIM(NVL(:uom,' ')))
          AND UPPER(TRIM(NVL(presentation,' '))) = UPPER(TRIM(NVL(:presentation,' ')))
          AND (:product_id IS NULL OR product_id <> :product_id)
        """,
        {
            "brand_id": brand_id,
            "description": description,
            "net_content": net_content,
            "uom": uom,
            "presentation": presentation,
            "product_id": product_id,
        },
    )
    if row["total"] > 0:
        raise ValueError("El producto ya existe con la misma marca, descripción, contenido y presentación.")


@app.context_processor
def globals_template():
    return {"current_year": datetime.now().year, "active_endpoint": request.endpoint}


@app.route("/")
def dashboard():
    cards = []
    error = None
    queries = [
        ("Productos", "SKU", "SELECT COUNT(*) total FROM SKU", "productos"),
        ("Marcas", "MARCA", "SELECT COUNT(*) total FROM MARCA", "master_list"),
        ("Categorías", "CATEGORIA", "SELECT COUNT(*) total FROM CATEGORIA", "master_list"),
        ("Retailers", "RETAILER", "SELECT COUNT(*) total FROM RETAILER", "master_list"),
        ("Puntos de venta", "PUNTO_VENTA", "SELECT COUNT(*) total FROM PUNTO_VENTA", "master_list"),
        ("Mercados", "MERCADO", "SELECT COUNT(*) total FROM MERCADO", "master_list"),
    ]
    try:
        for title, table, sql, endpoint in queries:
            total = fetch_one(sql)["total"]
            href = url_for(endpoint) if endpoint == "productos" else url_for(endpoint, nombre=table.lower())
            cards.append({"title": title, "total": total, "table": table, "href": href})
    except Exception as e:
        error = oracle_message(e)
    return render_template("dashboard.html", cards=cards, db_error=error)


@app.route("/conexion")
def conexion():
    try:
        return render_template("conexion.html", ok=True, info=test_connection())
    except Exception as e:
        return render_template("conexion.html", ok=False, error=oracle_message(e)), 503


# ---------------- PRODUCTOS / SKU ----------------
@app.route("/productos")
def productos():
    q = request.args.get("q", "").strip()
    estado = request.args.get("estado", "").strip()
    marca = request.args.get("marca", "").strip()
    categoria = request.args.get("categoria", "").strip()
    sql = """
    SELECT s.product_id, s.sku_code, s.description, s.net_content, s.uom,
           s.presentation, s.status, m.name marca,
           (SELECT MIN(pg.gtin) FROM PRODUCTOS_GTIN pg WHERE pg.product_id=s.product_id) gtin,
           (SELECT COUNT(*) FROM PRODUCTOS_GTIN pg WHERE pg.product_id=s.product_id) gtins,
           (SELECT LISTAGG(c.name, ' / ') WITHIN GROUP (ORDER BY c.level_no,c.name)
              FROM PRODUCTO_CATEGORIA pc JOIN CATEGORIA c ON c.category_id=pc.category_id
             WHERE pc.product_id=s.product_id) categoria
      FROM SKU s LEFT JOIN MARCA m ON m.brand_id=s.brand_id
     WHERE (:q IS NULL OR UPPER(NVL(s.sku_code,' ')) LIKE :likeq OR UPPER(s.description) LIKE :likeq
            OR EXISTS (SELECT 1 FROM PRODUCTOS_GTIN pg WHERE pg.product_id=s.product_id AND UPPER(pg.gtin) LIKE :likeq))
       AND (:estado IS NULL OR s.status=:estado)
       AND (:marca IS NULL OR TO_CHAR(s.brand_id)=:marca)
       AND (:categoria IS NULL OR EXISTS (SELECT 1 FROM PRODUCTO_CATEGORIA pc WHERE pc.product_id=s.product_id AND TO_CHAR(pc.category_id)=:categoria))
     ORDER BY s.product_id DESC
    """
    try:
        params = {
            "q": q or None,
            "likeq": f"%{q.upper()}%" if q else None,
            "estado": estado or None,
            "marca": marca or None,
            "categoria": categoria or None,
        }
        rows = fetch_all(sql, params)
        marcas = fetch_all("SELECT brand_id,name FROM MARCA ORDER BY name")
        categorias = fetch_all("SELECT category_id,name FROM CATEGORIA ORDER BY level_no,name")
        error = None
    except Exception as e:
        rows, marcas, categorias, error = [], [], [], oracle_message(e)
    return render_template(
        "productos.html",
        productos=rows,
        marcas=marcas,
        categorias=categorias,
        q=q,
        estado=estado,
        marca_sel=marca,
        categoria_sel=categoria,
        db_error=error,
    )


def product_lookups():
    return (
        fetch_all("SELECT brand_id,name FROM MARCA WHERE status='ACTIVE' ORDER BY name"),
        fetch_all("SELECT category_id, code, name, level_no FROM CATEGORIA WHERE status='ACTIVE' ORDER BY level_no,name"),
    )


@app.route("/productos/nuevo", methods=["GET", "POST"])
def producto_nuevo():
    if request.method == "POST":
        try:
            sku_code = n(request.form.get("sku_code"))
            brand_id = n(request.form.get("brand_id"), "int")
            description = n(request.form.get("description"))
            net_content = n(request.form.get("net_content"), "float")
            uom = n(request.form.get("uom"))
            presentation = n(request.form.get("presentation"))
            status = request.form.get("status", "ACTIVE")

            if not description:
                raise ValueError("Debe indicar la descripción del producto.")
            if brand_id is None:
                raise ValueError("Debe seleccionar una marca.")

            validate_sku_duplicate(brand_id, description, net_content, uom, presentation)

            # Se mantiene el procedimiento existente del RetailMan.sql.
            callproc(
                "SP_CREAR_SKU",
                [sku_code, brand_id, description, net_content, uom, presentation, status],
            )
            flash("Producto creado correctamente.", "success")
            return redirect(url_for("productos"))
        except Exception as e:
            flash(oracle_message(e), "error")
    try:
        marcas, categorias = product_lookups()
    except Exception:
        marcas, categorias = [], []
    return render_template("producto_form.html", producto=None, marcas=marcas, categorias=categorias)


@app.route("/productos/<int:product_id>/editar", methods=["GET", "POST"])
def producto_editar(product_id):
    producto = fetch_one("SELECT * FROM SKU WHERE product_id=:id", {"id": product_id})
    if not producto:
        abort(404)

    if request.method == "POST":
        try:
            sku_code = n(request.form.get("sku_code"))
            brand_id = n(request.form.get("brand_id"), "int")
            description = n(request.form.get("description"))
            net_content = n(request.form.get("net_content"), "float")
            uom = n(request.form.get("uom"))
            presentation = n(request.form.get("presentation"))
            status = request.form.get("status", "ACTIVE")

            if not description:
                raise ValueError("Debe indicar la descripción del producto.")
            if brand_id is None:
                raise ValueError("Debe seleccionar una marca.")

            validate_sku_duplicate(
                brand_id, description, net_content, uom, presentation, product_id=product_id
            )

            callproc(
                "SP_ACTUALIZAR_SKU",
                [product_id, sku_code, brand_id, description, net_content, uom, presentation, status],
            )
            flash("Producto actualizado correctamente.", "success")
            return redirect(url_for("productos"))
        except Exception as e:
            flash(oracle_message(e), "error")

    marcas, categorias = product_lookups()
    gtins = fetch_all("SELECT gtin FROM PRODUCTOS_GTIN WHERE product_id=:id ORDER BY gtin", {"id": product_id})
    asignadas = fetch_all(
        """
        SELECT pc.category_id, c.name, c.level_no
        FROM PRODUCTO_CATEGORIA pc
        JOIN CATEGORIA c ON c.category_id=pc.category_id
        WHERE pc.product_id=:id
        ORDER BY c.level_no,c.name
        """,
        {"id": product_id},
    )
    return render_template(
        "producto_form.html",
        producto=producto,
        marcas=marcas,
        categorias=categorias,
        gtins=gtins,
        asignadas=asignadas,
        asignadas_ids=[x["category_id"] for x in asignadas],
    )


@app.post("/productos/<int:product_id>/desactivar")
def producto_desactivar(product_id):
    try:
        callproc("SP_ELIMINAR_SKU", [product_id])
        flash("Producto desactivado correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("productos"))


@app.post("/productos/<int:product_id>/gtin")
def producto_gtin(product_id):
    try:
        gtin = n(request.form.get("gtin"))
        if not gtin:
            raise ValueError("Debe indicar el GTIN.")
        callproc("PD_REGISTRAR_PRODUCTO_GTIN", [product_id, gtin])
        flash("GTIN asociado correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


@app.post("/productos/<int:product_id>/gtin/eliminar")
def producto_gtin_eliminar(product_id):
    try:
        gtin = n(request.form.get("gtin"))
        callproc("PD_ELIMINAR_PRODUCTO_GTIN", [product_id, gtin])
        flash("GTIN eliminado correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


@app.post("/productos/<int:product_id>/categoria")
def producto_categoria(product_id):
    try:
        category_id = n(request.form.get("category_id"), "int")
        if category_id is None:
            raise ValueError("Debe seleccionar una categoría.")
        callproc("SP_ASIGNAR_PRODUCTO_CATEGORIA", [product_id, category_id])
        flash("Categoría asignada correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


@app.post("/productos/<int:product_id>/categoria/eliminar")
def producto_categoria_eliminar(product_id):
    try:
        category_id = n(request.form.get("category_id"), "int")
        callproc("SP_ELIMINAR_PRODUCTO_CATEGORIA", [product_id, category_id])
        flash("Categoría desasociada correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


# ---------------- MAESTROS ----------------
MASTER = {
    "mercado": {
        "title": "Mercados",
        "table": "MERCADO",
        "pk": "market_id",
        "fields": [("iso_code", "Código ISO", "text", True), ("name", "Nombre", "text", True)],
    },
    "canal": {
        "title": "Canales",
        "table": "CANAL",
        "pk": "channel_id",
        "fields": [("code", "Código", "text", True), ("name", "Nombre", "text", True)],
    },
    "retailer": {
        "title": "Retailers",
        "table": "RETAILER",
        "pk": "retailer_id",
        "fields": [("code", "Código", "text", True), ("name", "Nombre", "text", True), ("status", "Estado", "status", True)],
    },
    "formato": {
        "title": "Formatos",
        "table": "FORMATO",
        "pk": "format_id",
        "fields": [("code", "Código", "text", True), ("name", "Nombre", "text", True)],
    },
    "fabricante": {
        "title": "Fabricantes",
        "table": "FABRICANTE",
        "pk": "manufacturer_id",
        "fields": [("name", "Nombre", "text", True), ("country_code", "Código país", "text", False)],
    },
    "marca": {
        "title": "Marcas",
        "table": "MARCA",
        "pk": "brand_id",
        "fields": [("manufacturer_id", "Fabricante", "fabricante", True), ("name", "Nombre", "text", True), ("status", "Estado", "status", True)],
    },
    "categoria": {
        "title": "Categorías",
        "table": "CATEGORIA",
        "pk": "category_id",
        "fields": [("code", "Código", "text", False), ("name", "Nombre", "text", True), ("level_no", "Nivel", "number", True), ("parent_id", "Categoría padre", "categoria", False), ("status", "Estado", "status", True)],
    },
    "punto_venta": {
        "title": "Puntos de venta",
        "table": "PUNTO_VENTA",
        "pk": "store_id",
        "fields": [("retailer_id", "Retailer", "retailer", True), ("market_id", "Mercado", "mercado", True), ("channel_id", "Canal", "canal", True), ("code", "Código", "text", True), ("name", "Nombre", "text", True), ("zone", "Zona", "text", True), ("address", "Dirección", "text", True), ("status", "Estado", "status", True)],
    },
}

LOOKUPS = {
    "fabricante": "SELECT manufacturer_id id,name label FROM FABRICANTE ORDER BY name",
    "categoria": "SELECT category_id id, 'Nivel '||level_no||' · '||name label FROM CATEGORIA WHERE status='ACTIVE' ORDER BY level_no,name",
    "retailer": "SELECT retailer_id id,name label FROM RETAILER WHERE status='ACTIVE' ORDER BY name",
    "mercado": "SELECT market_id id,name label FROM MERCADO ORDER BY name",
    "canal": "SELECT channel_id id,name label FROM CANAL ORDER BY name",
}


def config(nombre):
    if nombre not in MASTER:
        abort(404)
    return MASTER[nombre]


def lookup_data(cfg, item_id=None):
    result = {}
    for name, _, kind, _ in cfg["fields"]:
        if kind in LOOKUPS:
            sql = LOOKUPS[kind]
            if kind == "categoria" and item_id:
                sql = """
                    SELECT category_id id, 'Nivel '||level_no||' · '||name label
                    FROM CATEGORIA
                    WHERE status='ACTIVE' AND category_id <> :item_id
                    ORDER BY level_no,name
                """
                result[name] = fetch_all(sql, {"item_id": item_id})
            else:
                result[name] = fetch_all(sql)
    return result


@app.route("/maestros/<nombre>")
def master_list(nombre):
    cfg = config(nombre)
    q = request.args.get("q", "").strip()
    try:
        cols = [cfg["pk"]] + [f[0] for f in cfg["fields"]]
        where = ""
        params = {}
        text_cols = [f[0] for f in cfg["fields"] if f[2] in ("text", "status")]
        if q and text_cols:
            where = " WHERE " + " OR ".join([f"UPPER(TO_CHAR({c})) LIKE :q" for c in text_cols])
            params["q"] = f"%{q.upper()}%"
        rows = fetch_all(f"SELECT {','.join(cols)} FROM {cfg['table']}{where} ORDER BY {cfg['pk']} DESC", params)
        err = None
    except Exception as e:
        rows, err = [], oracle_message(e)
    return render_template("master_list.html", nombre=nombre, config=cfg, rows=rows, q=q, db_error=err)


@app.route("/maestros/<nombre>/nuevo", methods=["GET", "POST"])
def master_new(nombre):
    cfg = config(nombre)
    extra = {}

    if request.method == "POST":
        try:
            if nombre == "categoria":
                name = n(request.form.get("name"))
                level_no = n(request.form.get("level_no"), "int")
                parent_id = n(request.form.get("parent_id"), "int")
                status = request.form.get("status", "ACTIVE")
                validate_category(name, level_no, parent_id)
                callproc("PKG_CATEGORIA.SP_CREAR_CATEGORIA", [name, level_no, parent_id, status])

            elif nombre == "fabricante":
                callproc_out_number(
                    "PKG_FABRICANTE.PR_CREAR_FABRICANTE",
                    [n(request.form.get("name")), n(request.form.get("country_code"))],
                )

            elif nombre == "marca":
                callproc_out_number(
                    "PKG_MARCA.PR_CREAR_MARCA",
                    [n(request.form.get("manufacturer_id"), "int"), n(request.form.get("name")), request.form.get("status", "ACTIVE")],
                )

            elif nombre == "retailer":
                market_id = n(request.form.get("market_id"), "int")
                if market_id is None:
                    raise ValueError("Debe seleccionar el mercado inicial del retailer.")
                callproc_out_number(
                    "PKG_RETAILER.PR_CREAR_RETAILER",
                    [market_id, n(request.form.get("code")), n(request.form.get("name"))],
                )

            elif nombre == "punto_venta":
                result = callproc_out_number(
                    "PR_REGISTRAR_PUNTO_VENTA",
                    [
                        n(request.form.get("retailer_id"), "int"),
                        n(request.form.get("market_id"), "int"),
                        n(request.form.get("channel_id"), "int"),
                        n(request.form.get("code")),
                        n(request.form.get("name")),
                        n(request.form.get("zone")),
                        n(request.form.get("address")),
                    ],
                )
                if not result:
                    raise ValueError("Oracle no pudo registrar el punto de venta.")

            elif nombre == "formato":
                code = n(request.form.get("code"))
                name = n(request.form.get("name"))
                duplicate = fetch_one(
                    "SELECT COUNT(*) total FROM FORMATO WHERE UPPER(TRIM(code))=UPPER(TRIM(:code)) OR UPPER(TRIM(name))=UPPER(TRIM(:name))",
                    {"code": code, "name": name},
                )["total"]
                if duplicate > 0:
                    raise ValueError("Ya existe un formato con ese código o nombre.")
                result = callproc_out_number("PR_REGISTRAR_FORMATO", [code, name])
                if not result:
                    raise ValueError("Oracle no pudo registrar el formato.")

            elif nombre == "mercado":
                callproc("PKG_MERCADO.SP_CREAR_MERCADO", [n(request.form.get("iso_code")), n(request.form.get("name"))])

            elif nombre == "canal":
                callproc("PKG_CANAL.SP_CREAR_CANAL", [n(request.form.get("code")), n(request.form.get("name"))])

            else:
                fields = [f[0] for f in cfg["fields"]]
                vals = {
                    x: n(
                        request.form.get(x),
                        "int" if next(f for f in cfg["fields"] if f[0] == x)[2] in ("number", "fabricante", "categoria", "retailer", "mercado", "canal") else "text",
                    )
                    for x in fields
                }
                execute(f"INSERT INTO {cfg['table']} ({','.join(fields)}) VALUES ({','.join(':'+x for x in fields)})", vals)

            flash(f"Registro creado correctamente en {cfg['title']}.", "success")
            return redirect(url_for("master_list", nombre=nombre))
        except Exception as e:
            flash(oracle_message(e), "error")

    if nombre == "retailer":
        extra["mercados"] = fetch_all("SELECT market_id id,name label FROM MERCADO ORDER BY name")
    return render_template("master_form.html", nombre=nombre, config=cfg, row=None, lookups=lookup_data(cfg), extra=extra)


@app.route("/maestros/<nombre>/<int:item_id>/editar", methods=["GET", "POST"])
def master_edit(nombre, item_id):
    cfg = config(nombre)
    row = fetch_one(f"SELECT * FROM {cfg['table']} WHERE {cfg['pk']}=:id", {"id": item_id})
    if not row:
        abort(404)

    if request.method == "POST":
        try:
            if nombre == "categoria":
                code = n(request.form.get("code"))
                name = n(request.form.get("name"))
                level_no = n(request.form.get("level_no"), "int")
                parent_id = n(request.form.get("parent_id"), "int")
                status = request.form.get("status", "ACTIVE")
                validate_category(name, level_no, parent_id, category_id=item_id)
                callproc("PKG_CATEGORIA.SP_ACTUALIZAR_CATEGORIA", [item_id, code, name, level_no, parent_id, status])

            elif nombre == "fabricante":
                callproc(
                    "PKG_FABRICANTE.PR_ACTUALIZAR_FABRICANTE",
                    [item_id, n(request.form.get("name")), n(request.form.get("country_code"))],
                )

            elif nombre == "marca":
                callproc(
                    "PKG_MARCA.PR_ACTUALIZAR_MARCA",
                    [item_id, n(request.form.get("manufacturer_id"), "int"), n(request.form.get("name")), request.form.get("status", "ACTIVE")],
                )

            elif nombre == "retailer":
                callproc(
                    "PKG_RETAILER.PR_ACTUALIZAR_RETAILER",
                    [item_id, n(request.form.get("code")), n(request.form.get("name")), request.form.get("status", "ACTIVE")],
                )

            elif nombre == "punto_venta":
                result = callproc_out_number(
                    "PR_ACTUALIZAR_PUNTO_VENTA",
                    [
                        item_id,
                        n(request.form.get("channel_id"), "int"),
                        n(request.form.get("name")),
                        n(request.form.get("zone")),
                        n(request.form.get("address")),
                        request.form.get("status", "ACTIVE"),
                    ],
                )
                if not result:
                    raise ValueError("Oracle no pudo actualizar el punto de venta.")

            elif nombre == "formato":
                code = n(request.form.get("code"))
                name = n(request.form.get("name"))
                duplicate = fetch_one(
                    """
                    SELECT COUNT(*) total FROM FORMATO
                    WHERE format_id <> :id
                      AND (UPPER(TRIM(code))=UPPER(TRIM(:code)) OR UPPER(TRIM(name))=UPPER(TRIM(:name)))
                    """,
                    {"id": item_id, "code": code, "name": name},
                )["total"]
                if duplicate > 0:
                    raise ValueError("Ya existe otro formato con ese código o nombre.")
                result = callproc_out_number("PR_ACTUALIZAR_FORMATO", [item_id, code, name])
                if not result:
                    raise ValueError("Oracle no pudo actualizar el formato.")

            elif nombre == "mercado":
                callproc("PKG_MERCADO.SP_ACTUALIZAR_MERCADO", [item_id, n(request.form.get("iso_code")), n(request.form.get("name"))])

            elif nombre == "canal":
                callproc("PKG_CANAL.SP_ACTUALIZAR_CANAL", [item_id, n(request.form.get("code")), n(request.form.get("name"))])

            else:
                vals = {}
                for fname, _, kind, _ in cfg["fields"]:
                    vals[fname] = n(request.form.get(fname), "int" if kind in ("number", "fabricante", "categoria", "retailer", "mercado", "canal") else "text")
                vals["id"] = item_id
                execute(f"UPDATE {cfg['table']} SET " + ",".join(f"{f[0]}=:{f[0]}" for f in cfg["fields"]) + f" WHERE {cfg['pk']}=:id", vals)

            flash("Registro actualizado correctamente.", "success")
            return redirect(url_for("master_list", nombre=nombre))
        except Exception as e:
            flash(oracle_message(e), "error")

    extra = {}
    if nombre == "retailer":
        extra["mercados"] = fetch_all("SELECT market_id id,name label FROM MERCADO ORDER BY name")
        extra["mercados_asociados"] = fetch_all(
            """
            SELECT rm.market_id, m.name mercado
            FROM RETAILER_MERCADO rm
            JOIN MERCADO m ON m.market_id=rm.market_id
            WHERE rm.retailer_id=:id
            ORDER BY m.name
            """,
            {"id": item_id},
        )
    elif nombre == "formato":
        extra["retailers"] = fetch_all("SELECT retailer_id id,name label FROM RETAILER WHERE status='ACTIVE' ORDER BY name")
        extra["retailers_asociados"] = fetch_all(
            """
            SELECT rf.retailer_format_id, rf.retailer_id, r.name retailer,
                   rf.name nombre_comercial, rf.status estado
            FROM RETAILER_FORMATO rf
            JOIN RETAILER r ON r.retailer_id=rf.retailer_id
            WHERE rf.format_id=:id
            ORDER BY r.name, rf.name
            """,
            {"id": item_id},
        )

    return render_template("master_form.html", nombre=nombre, config=cfg, row=row, lookups=lookup_data(cfg, item_id), extra=extra)


# Gestión de mercados directamente desde Editar Retailer (Req. 7)
@app.post("/maestros/retailer/<int:retailer_id>/mercados/asociar")
def retailer_mercado_asociar(retailer_id):
    try:
        market_id = n(request.form.get("market_id"), "int")
        if market_id is None:
            raise ValueError("Debe seleccionar un mercado.")
        callproc("PKG_RETAILER.PR_ASOCIAR_MERCADO", [retailer_id, market_id])
        flash("Mercado asociado al retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("master_edit", nombre="retailer", item_id=retailer_id))


@app.post("/maestros/retailer/<int:retailer_id>/mercados/<int:market_id>/desasociar")
def retailer_mercado_desasociar(retailer_id, market_id):
    try:
        callproc("PKG_RETAILER.PR_DESASOCIAR_MERCADO", [retailer_id, market_id])
        flash("Mercado desasociado del retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("master_edit", nombre="retailer", item_id=retailer_id))


# Gestión de retailers directamente desde Editar Formato (Req. 9)
@app.post("/maestros/formato/<int:format_id>/retailers/asociar")
def formato_retailer_asociar(format_id):
    try:
        retailer_id = n(request.form.get("retailer_id"), "int")
        name = n(request.form.get("name"))
        if retailer_id is None:
            raise ValueError("Debe seleccionar un retailer.")
        if not name:
            raise ValueError("Debe indicar el nombre comercial de la asociación.")
        result = callproc_out_number("PR_ASOCIAR_FORMATO_RETAILER", [retailer_id, format_id, name])
        if not result:
            raise ValueError("Oracle no pudo crear la asociación retailer-formato.")
        flash("Formato asociado al retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("master_edit", nombre="formato", item_id=format_id))


@app.post("/maestros/formato/<int:format_id>/retailers/<int:rel_id>/desactivar")
def formato_retailer_desactivar(format_id, rel_id):
    try:
        result = callproc_out_number("PR_ELIMINAR_RETAILER_FORMATO", [rel_id])
        if not result:
            raise ValueError("Oracle no pudo inactivar la asociación retailer-formato.")
        flash("Asociación retailer-formato inactivada correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("master_edit", nombre="formato", item_id=format_id))


@app.post("/maestros/<nombre>/<int:item_id>/eliminar")
def master_delete(nombre, item_id):
    cfg = config(nombre)
    try:
        if nombre == "categoria":
            callproc("PKG_CATEGORIA.SP_ELIMINAR_CATEGORIA", [item_id])
            flash("Categoría inactivada correctamente.", "success")
        elif nombre == "fabricante":
            callproc("PKG_FABRICANTE.PR_ELIMINAR_FABRICANTE", [item_id])
            flash("Fabricante eliminado correctamente.", "success")
        elif nombre == "marca":
            callproc("PKG_MARCA.PR_ELIMINAR_MARCA", [item_id])
            flash("Marca eliminada correctamente.", "success")
        elif nombre == "retailer":
            row = fetch_one("SELECT status FROM RETAILER WHERE retailer_id=:id", {"id": item_id})
            new_status = "ACTIVE" if row and row["status"] == "INACTIVE" else "INACTIVE"
            callproc("PKG_RETAILER.PR_CAMBIAR_ESTADO_RETAILER", [item_id, new_status])
            flash(f"Retailer {'activado' if new_status == 'ACTIVE' else 'inactivado'} correctamente.", "success")
        elif nombre == "punto_venta":
            result = callproc_out_number("PR_ELIMINAR_PUNTO_VENTA", [item_id])
            if not result:
                raise ValueError("Oracle no pudo inactivar el punto de venta.")
            flash("Punto de venta inactivado correctamente.", "success")
        elif nombre == "formato":
            result = callproc_out_number("PR_ELIMINAR_FORMATO", [item_id])
            if not result:
                raise ValueError("Oracle no pudo eliminar el formato.")
            flash("Formato eliminado correctamente.", "success")
        elif nombre == "mercado":
            callproc("PKG_MERCADO.SP_ELIMINAR_MERCADO", [item_id])
            flash("Mercado eliminado correctamente.", "success")
        elif nombre == "canal":
            callproc("PKG_CANAL.SP_ELIMINAR_CANAL", [item_id])
            flash("Canal eliminado correctamente.", "success")
        else:
            if any(f[0] == "status" for f in cfg["fields"]):
                execute(f"UPDATE {cfg['table']} SET status='INACTIVE' WHERE {cfg['pk']}=:id", {"id": item_id})
                flash("Registro desactivado correctamente.", "success")
            else:
                execute(f"DELETE FROM {cfg['table']} WHERE {cfg['pk']}=:id", {"id": item_id})
                flash("Registro eliminado correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("master_list", nombre=nombre))


# ---------------- RELACIONES ----------------
@app.route("/relaciones")
def relaciones():
    try:
        retailer_mercado = fetch_all(
            """
            SELECT rm.retailer_id, r.name retailer, rm.market_id, m.name mercado
            FROM RETAILER_MERCADO rm
            JOIN RETAILER r ON r.retailer_id=rm.retailer_id
            JOIN MERCADO m ON m.market_id=rm.market_id
            ORDER BY r.name,m.name
            """
        )
        retailer_formato = fetch_all(
            """
            SELECT rf.retailer_format_id, rf.retailer_id, r.name retailer,
                   rf.format_id, f.name formato, rf.name nombre_comercial, rf.status estado
            FROM RETAILER_FORMATO rf
            JOIN RETAILER r ON r.retailer_id=rf.retailer_id
            JOIN FORMATO f ON f.format_id=rf.format_id
            ORDER BY r.name,f.name,rf.name
            """
        )
        producto_categoria = fetch_all(
            """
            SELECT pc.product_id, s.sku_code sku, s.description producto,
                   pc.category_id, c.name categoria
            FROM PRODUCTO_CATEGORIA pc
            JOIN SKU s ON s.product_id=pc.product_id
            JOIN CATEGORIA c ON c.category_id=pc.category_id
            ORDER BY s.description,c.name
            """
        )
        producto_gtin = fetch_all(
            """
            SELECT pg.product_id, s.sku_code sku, s.description producto, pg.gtin
            FROM PRODUCTOS_GTIN pg
            JOIN SKU s ON s.product_id=pg.product_id
            ORDER BY s.description,pg.gtin
            """
        )
        retailers = fetch_all("SELECT retailer_id id,name label FROM RETAILER WHERE status='ACTIVE' ORDER BY name")
        mercados = fetch_all("SELECT market_id id,name label FROM MERCADO ORDER BY name")
        formatos = fetch_all("SELECT format_id id,name label FROM FORMATO ORDER BY name")
        error = None
    except Exception as e:
        retailer_mercado = retailer_formato = producto_categoria = producto_gtin = []
        retailers = mercados = formatos = []
        error = oracle_message(e)

    return render_template(
        "relaciones.html",
        retailer_mercado=retailer_mercado,
        retailer_formato=retailer_formato,
        producto_categoria=producto_categoria,
        producto_gtin=producto_gtin,
        retailers=retailers,
        mercados=mercados,
        formatos=formatos,
        db_error=error,
    )


@app.post("/relaciones/retailer-mercado")
def relacion_retailer_mercado():
    try:
        retailer_id = n(request.form.get("retailer_id"), "int")
        market_id = n(request.form.get("market_id"), "int")
        callproc("PKG_RETAILER.PR_ASOCIAR_MERCADO", [retailer_id, market_id])
        flash("Mercado asociado al retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("relaciones"))


@app.post("/relaciones/retailer-mercado/eliminar")
def relacion_retailer_mercado_eliminar():
    try:
        retailer_id = n(request.form.get("retailer_id"), "int")
        market_id = n(request.form.get("market_id"), "int")
        callproc("PKG_RETAILER.PR_DESASOCIAR_MERCADO", [retailer_id, market_id])
        flash("Mercado desasociado del retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("relaciones"))


@app.post("/relaciones/retailer-formato")
def relacion_retailer_formato():
    try:
        retailer_id = n(request.form.get("retailer_id"), "int")
        format_id = n(request.form.get("format_id"), "int")
        name = n(request.form.get("name"))
        result = callproc_out_number("PR_ASOCIAR_FORMATO_RETAILER", [retailer_id, format_id, name])
        if not result:
            raise ValueError("Oracle no pudo crear la asociación retailer-formato.")
        flash("Formato asociado al retailer correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("relaciones"))


@app.post("/relaciones/retailer-formato/<int:rel_id>/desactivar")
def relacion_retailer_formato_desactivar(rel_id):
    try:
        result = callproc_out_number("PR_ELIMINAR_RETAILER_FORMATO", [rel_id])
        if not result:
            raise ValueError("Oracle no pudo inactivar la asociación retailer-formato.")
        flash("Asociación retailer-formato inactivada correctamente.", "success")
    except Exception as e:
        flash(oracle_message(e), "error")
    return redirect(url_for("relaciones"))


# ---------------- CATÁLOGO MAESTRO / REQ. 10 ----------------
@app.route("/catalogo/<int:product_id>")
def catalogo_detalle(product_id):
    producto = fetch_one(
        """
        SELECT s.*, m.name marca, f.name fabricante
        FROM SKU s
        LEFT JOIN MARCA m ON m.brand_id=s.brand_id
        LEFT JOIN FABRICANTE f ON f.manufacturer_id=m.manufacturer_id
        WHERE s.product_id=:id
        """,
        {"id": product_id},
    )
    if not producto:
        abort(404)

    categorias = fetch_all(
        """
        SELECT c.category_id,c.code,c.name,c.level_no
        FROM PRODUCTO_CATEGORIA pc
        JOIN CATEGORIA c ON c.category_id=pc.category_id
        WHERE pc.product_id=:id
        ORDER BY c.level_no,c.name
        """,
        {"id": product_id},
    )
    gtins = fetch_all("SELECT gtin FROM PRODUCTOS_GTIN WHERE product_id=:id ORDER BY gtin", {"id": product_id})

    # RetailMan.sql sí define la relación RETAILER -> MERCADO -> PUNTO_VENTA.
    # No existe una FK directa SKU -> RETAILER/PUNTO_VENTA, por lo que mostramos
    # la relación comercial real sin inventar una asociación directa con el SKU.
    estructura_comercial = fetch_all(
        """
        SELECT r.retailer_id, r.name retailer,
               m.market_id, m.name mercado,
               pv.store_id, pv.name punto_venta, pv.zone, pv.address, pv.status
        FROM RETAILER r
        JOIN RETAILER_MERCADO rm ON rm.retailer_id=r.retailer_id
        JOIN MERCADO m ON m.market_id=rm.market_id
        LEFT JOIN PUNTO_VENTA pv
          ON pv.retailer_id=rm.retailer_id
         AND pv.market_id=rm.market_id
        ORDER BY r.name, m.name, pv.name
        """
    )
    return render_template(
        "catalogo_detalle.html",
        producto=producto,
        categorias=categorias,
        gtins=gtins,
        estructura_comercial=estructura_comercial,
    )


@app.errorhandler(404)
def not_found(e):
    return render_template("error.html", title="Página no encontrada", message="La ruta o registro solicitado no existe."), 404


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=os.getenv("FLASK_DEBUG", "1") == "1")
