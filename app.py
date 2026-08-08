


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
    if kind == "int": return int(value)
    if kind == "float": return float(value)
    return value


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
        params={"q":q or None,"likeq":f"%{q.upper()}%" if q else None,"estado":estado or None,"marca":marca or None,"categoria":categoria or None}
        rows=fetch_all(sql,params)
        marcas=fetch_all("SELECT brand_id,name FROM MARCA ORDER BY name")
        categorias=fetch_all("SELECT category_id,name FROM CATEGORIA ORDER BY level_no,name")
        error=None
    except Exception as e:
        rows=[]; marcas=[]; categorias=[]; error=oracle_message(e)
    return render_template("productos.html", productos=rows, marcas=marcas, categorias=categorias, q=q, estado=estado, marca_sel=marca, categoria_sel=categoria, db_error=error)


def product_lookups():
    return (
        fetch_all("SELECT brand_id,name FROM MARCA WHERE status='ACTIVE' ORDER BY name"),
        fetch_all("SELECT category_id, code, name, level_no FROM CATEGORIA WHERE status='ACTIVE' ORDER BY level_no,name")
    )


@app.route("/productos/nuevo", methods=["GET","POST"])
def producto_nuevo():
    if request.method == "POST":
        try:
            with get_connection() as con:
                with con.cursor() as cur:
                    # El procedimiento SP_CREAR_SKU pertenece a RetailMan.sql
                    cur.callproc("SP_CREAR_SKU", [
                        n(request.form.get("sku_code")), n(request.form.get("brand_id"),"int"),
                        n(request.form.get("description")), n(request.form.get("net_content"),"float"),
                        n(request.form.get("uom")), n(request.form.get("presentation")), request.form.get("status","ACTIVE")
                    ])
                con.commit()
            flash("Producto creado correctamente.", "success")
            return redirect(url_for("productos"))
        except Exception as e: flash(oracle_message(e), "error")
    try: marcas,categorias=product_lookups()
    except Exception: marcas,categorias=[],[]
    return render_template("producto_form.html", producto=None, marcas=marcas, categorias=categorias)


@app.route("/productos/<int:product_id>/editar", methods=["GET","POST"])
def producto_editar(product_id):
    producto=fetch_one("SELECT * FROM SKU WHERE product_id=:id", {"id":product_id})
    if not producto: abort(404)
    if request.method == "POST":
        try:
            with get_connection() as con:
                with con.cursor() as cur:
                    cur.callproc("SP_ACTUALIZAR_SKU", [
                        product_id, n(request.form.get("sku_code")), n(request.form.get("brand_id"),"int"),
                        n(request.form.get("description")), n(request.form.get("net_content"),"float"),
                        n(request.form.get("uom")), n(request.form.get("presentation")), request.form.get("status","ACTIVE")
                    ])
                con.commit()
            flash("Producto actualizado correctamente.", "success")
            return redirect(url_for("productos"))
        except Exception as e: flash(oracle_message(e), "error")
    marcas,categorias=product_lookups()
    gtins=fetch_all("SELECT gtin FROM PRODUCTOS_GTIN WHERE product_id=:id ORDER BY gtin", {"id":product_id})
    asignadas=fetch_all("SELECT category_id FROM PRODUCTO_CATEGORIA WHERE product_id=:id", {"id":product_id})
    return render_template("producto_form.html", producto=producto, marcas=marcas, categorias=categorias, gtins=gtins, asignadas=[x['category_id'] for x in asignadas])


@app.post("/productos/<int:product_id>/desactivar")
def producto_desactivar(product_id):
    try:
        with get_connection() as con:
            with con.cursor() as cur: cur.callproc("SP_ELIMINAR_SKU", [product_id])
            con.commit()
        flash("Producto desactivado correctamente.", "success")
    except Exception as e: flash(oracle_message(e), "error")
    return redirect(url_for("productos"))


@app.post("/productos/<int:product_id>/gtin")
def producto_gtin(product_id):
    try:
        gtin=n(request.form.get("gtin"))
        with get_connection() as con:
            with con.cursor() as cur: cur.callproc("PD_REGISTRAR_PRODUCTO_GTIN", [product_id, gtin])
            con.commit()
        flash("GTIN asociado correctamente.", "success")
    except Exception as e: flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


@app.post("/productos/<int:product_id>/categoria")
def producto_categoria(product_id):
    try:
        category_id=n(request.form.get("category_id"),"int")
        with get_connection() as con:
            with con.cursor() as cur: cur.callproc("SP_ASIGNAR_PRODUCTO_CATEGORIA", [product_id, category_id])
            con.commit()
        flash("Categoría asignada correctamente.", "success")
    except Exception as e: flash(oracle_message(e), "error")
    return redirect(url_for("producto_editar", product_id=product_id))


# ---------------- MAESTROS ----------------
MASTER = {
 "mercado":{"title":"Mercados","table":"MERCADO","pk":"market_id","fields":[("iso_code","Código ISO","text",True),("name","Nombre","text",True)]},
 "canal":{"title":"Canales","table":"CANAL","pk":"channel_id","fields":[("code","Código","text",True),("name","Nombre","text",True)]},
 "retailer":{"title":"Retailers","table":"RETAILER","pk":"retailer_id","fields":[("code","Código","text",True),("name","Nombre","text",True),("status","Estado","status",True)]},
 "formato":{"title":"Formatos","table":"FORMATO","pk":"format_id","fields":[("code","Código","text",True),("name","Nombre","text",True)]},
 "fabricante":{"title":"Fabricantes","table":"FABRICANTE","pk":"manufacturer_id","fields":[("name","Nombre","text",True),("country_code","Código país","text",False)]},
 "marca":{"title":"Marcas","table":"MARCA","pk":"brand_id","fields":[("manufacturer_id","Fabricante","fabricante",True),("name","Nombre","text",True),("status","Estado","status",True)]},
 "categoria":{"title":"Categorías","table":"CATEGORIA","pk":"category_id","fields":[("code","Código","text",True),("name","Nombre","text",True),("level_no","Nivel","number",True),("parent_id","Categoría padre","categoria",False),("status","Estado","status",True)]},
 "punto_venta":{"title":"Puntos de venta","table":"PUNTO_VENTA","pk":"store_id","fields":[("retailer_id","Retailer","retailer",True),("market_id","Mercado","mercado",True),("channel_id","Canal","canal",True),("code","Código","text",True),("name","Nombre","text",True),("zone","Zona","text",False),("address","Dirección","text",False),("status","Estado","status",True)]},
}

LOOKUPS={
 "fabricante":("SELECT manufacturer_id id,name label FROM FABRICANTE ORDER BY name"),
 "categoria":("SELECT category_id id, name label FROM CATEGORIA WHERE status='ACTIVE' ORDER BY level_no,name"),
 "retailer":("SELECT retailer_id id,name label FROM RETAILER WHERE status='ACTIVE' ORDER BY name"),
 "mercado":("SELECT market_id id,name label FROM MERCADO ORDER BY name"),
 "canal":("SELECT channel_id id,name label FROM CANAL ORDER BY name"),
}


def config(nombre):
    if nombre not in MASTER: abort(404)
    return MASTER[nombre]


def lookup_data(cfg):
    result={}
    for name,_,kind,_ in cfg["fields"]:
        if kind in LOOKUPS:
            result[name]=fetch_all(LOOKUPS[kind])
    return result


@app.route("/maestros/<nombre>")
def master_list(nombre):
    cfg=config(nombre); q=request.args.get("q","").strip()
    try:
        cols=[cfg["pk"]]+[f[0] for f in cfg["fields"]]
        where=""
        params={}
        text_cols=[f[0] for f in cfg["fields"] if f[2] in ("text","status")]
        if q and text_cols:
            where=" WHERE "+" OR ".join([f"UPPER(TO_CHAR({c})) LIKE :q" for c in text_cols]); params["q"]=f"%{q.upper()}%"
        rows=fetch_all(f"SELECT {','.join(cols)} FROM {cfg['table']}{where} ORDER BY {cfg['pk']} DESC",params)
        err=None
    except Exception as e: rows=[]; err=oracle_message(e)
    return render_template("master_list.html", nombre=nombre, config=cfg, rows=rows, q=q, db_error=err)


@app.route("/maestros/<nombre>/nuevo", methods=["GET","POST"])
def master_new(nombre):
    cfg=config(nombre)
    if request.method=="POST":
        try:
            fields=[f[0] for f in cfg["fields"]]
            vals={x:n(request.form.get(x), "int" if next(f for f in cfg['fields'] if f[0]==x)[2] in ("number","fabricante","categoria","retailer","mercado","canal") else "text") for x in fields}
            execute(f"INSERT INTO {cfg['table']} ({','.join(fields)}) VALUES ({','.join(':'+x for x in fields)})",vals)
            flash(f"{cfg['title'][:-1] if cfg['title'].endswith('s') else cfg['title']} creado correctamente.","success")
            return redirect(url_for("master_list",nombre=nombre))
        except Exception as e: flash(oracle_message(e),"error")
    return render_template("master_form.html", nombre=nombre, config=cfg, row=None, lookups=lookup_data(cfg))


@app.route("/maestros/<nombre>/<int:item_id>/editar", methods=["GET","POST"])
def master_edit(nombre,item_id):
    cfg=config(nombre); row=fetch_one(f"SELECT * FROM {cfg['table']} WHERE {cfg['pk']}=:id",{"id":item_id})
    if not row: abort(404)
    if request.method=="POST":
        try:
            vals={}
            for fname,_,kind,_ in cfg["fields"]:
                vals[fname]=n(request.form.get(fname), "int" if kind in ("number","fabricante","categoria","retailer","mercado","canal") else "text")
            vals["id"]=item_id
            execute(f"UPDATE {cfg['table']} SET "+",".join(f"{f[0]}=:{f[0]}" for f in cfg['fields'])+f" WHERE {cfg['pk']}=:id",vals)
            flash("Registro actualizado correctamente.","success"); return redirect(url_for("master_list",nombre=nombre))
        except Exception as e: flash(oracle_message(e),"error")
    return render_template("master_form.html", nombre=nombre, config=cfg, row=row, lookups=lookup_data(cfg))


@app.post("/maestros/<nombre>/<int:item_id>/eliminar")
def master_delete(nombre,item_id):
    cfg=config(nombre)
    try:
        if any(f[0]=="status" for f in cfg["fields"]):
            execute(f"UPDATE {cfg['table']} SET status='INACTIVE' WHERE {cfg['pk']}=:id",{"id":item_id})
            flash("Registro desactivado correctamente.","success")
        else:
            execute(f"DELETE FROM {cfg['table']} WHERE {cfg['pk']}=:id",{"id":item_id})
            flash("Registro eliminado correctamente.","success")
    except Exception as e: flash(oracle_message(e),"error")
    return redirect(url_for("master_list",nombre=nombre))


# Relaciones importantes, lectura directa de RetailMan.sql
@app.route("/relaciones")
def relaciones():
    sections=[]
    queries=[
      ("Retailer - Mercado","SELECT r.name retailer, m.name mercado FROM RETAILER_MERCADO rm JOIN RETAILER r ON r.retailer_id=rm.retailer_id JOIN MERCADO m ON m.market_id=rm.market_id ORDER BY r.name,m.name"),
      ("Retailer - Formato","SELECT r.name retailer, f.name formato, rf.name nombre, rf.status estado FROM RETAILER_FORMATO rf JOIN RETAILER r ON r.retailer_id=rf.retailer_id JOIN FORMATO f ON f.format_id=rf.format_id ORDER BY r.name,f.name"),
      ("Producto - Categoría","SELECT s.sku_code sku, s.description producto, c.name categoria FROM PRODUCTO_CATEGORIA pc JOIN SKU s ON s.product_id=pc.product_id JOIN CATEGORIA c ON c.category_id=pc.category_id ORDER BY s.description,c.name"),
      ("Producto - GTIN","SELECT s.sku_code sku, s.description producto, pg.gtin FROM PRODUCTOS_GTIN pg JOIN SKU s ON s.product_id=pg.product_id ORDER BY s.description,pg.gtin"),
    ]
    try:
        for title,sql in queries: sections.append((title,fetch_all(sql)))
        error=None
    except Exception as e: error=oracle_message(e)
    return render_template("relaciones.html", sections=sections, db_error=error)


@app.errorhandler(404)
def not_found(e): return render_template("error.html", title="Página no encontrada", message="La ruta o registro solicitado no existe."),404

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=os.getenv("FLASK_DEBUG","1")=="1")