from flask import Flask, render_template, request
from datetime import datetime

app = Flask(__name__)

# Esta primera versión usa datos de ejemplo para construir aproximadamente
# el 50% visual del módulo de Productos.
PRODUCTOS = [
    {
        "sku": "SKU-100001",
        "gtin": "7501000654321",
        "descripcion": "Coca-Cola Original 2.5 L",
        "detalle": "Bebida carbonatada",
        "marca": "Coca-Cola",
        "categoria": "Bebidas > Gaseosas",
        "presentacion": "2.5 L",
        "envase": "Botella",
        "gtins": 2,
        "estado": "ACTIVE",
        "icono": "🥤",
    },
    {
        "sku": "SKU-100002",
        "gtin": "7501025409876",
        "descripcion": "Salsa de Tomate 400 g",
        "detalle": "Alimentos enlatados",
        "marca": "La Costeña",
        "categoria": "Alimentos > Salsas",
        "presentacion": "400 g",
        "envase": "Frasco",
        "gtins": 1,
        "estado": "ACTIVE",
        "icono": "🥫",
    },
    {
        "sku": "SKU-100003",
        "gtin": "7501030401234",
        "descripcion": "Cereal Corn Flakes 510 g",
        "detalle": "Cereales",
        "marca": "Kellogg's",
        "categoria": "Desayuno > Cereales",
        "presentacion": "510 g",
        "envase": "Caja",
        "gtins": 1,
        "estado": "ACTIVE",
        "icono": "🥣",
    },
    {
        "sku": "SKU-100004",
        "gtin": "7501045405678",
        "descripcion": "Detergente Ariel Líquido 1.8 L",
        "detalle": "Limpieza del hogar",
        "marca": "Ariel",
        "categoria": "Hogar > Lavandería",
        "presentacion": "1.8 L",
        "envase": "Botella",
        "gtins": 2,
        "estado": "ACTIVE",
        "icono": "🧴",
    },
    {
        "sku": "SKU-100005",
        "gtin": "7501050504321",
        "descripcion": "Chocolate Snickers 51 g",
        "detalle": "Confitería",
        "marca": "Snickers",
        "categoria": "Confitería > Chocolates",
        "presentacion": "51 g",
        "envase": "Barra",
        "gtins": 1,
        "estado": "ACTIVE",
        "icono": "🍫",
    },
    {
        "sku": "SKU-100006",
        "gtin": "7501060709876",
        "descripcion": "Leche Entera 1 L",
        "detalle": "Producto lácteo",
        "marca": "Dos Pinos",
        "categoria": "Lácteos > Leches",
        "presentacion": "1 L",
        "envase": "Caja",
        "gtins": 1,
        "estado": "INACTIVE",
        "icono": "🥛",
    },
]


@app.context_processor
def inject_now():
    return {"current_year": datetime.now().year}


@app.route("/")
def inicio():
    return render_template("productos.html", productos=PRODUCTOS)


@app.route("/productos")
def productos():
    texto = request.args.get("q", "").strip().lower()
    marca = request.args.get("marca", "").strip()
    estado = request.args.get("estado", "").strip()

    resultado = PRODUCTOS

    if texto:
        resultado = [
            p for p in resultado
            if texto in p["sku"].lower()
            or texto in p["gtin"].lower()
            or texto in p["descripcion"].lower()
        ]

    if marca:
        resultado = [p for p in resultado if p["marca"] == marca]

    if estado:
        resultado = [p for p in resultado if p["estado"] == estado]

    return render_template(
        "productos.html",
        productos=resultado,
        q=request.args.get("q", ""),
        marca_seleccionada=marca,
        estado_seleccionado=estado,
    )


@app.route("/proximamente")
def proximamente():
    return render_template("proximamente.html")


if __name__ == "__main__":
    # Se abre en: http://127.0.0.1:5000
    app.run(debug=True)
