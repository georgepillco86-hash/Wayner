<<<<<<< HEAD
# Ferrotienda Backend

Backend modular para consultar productos desde las vistas remotas:

- `v_kardexproductos`: precios, IVA, historial y stock estimado por movimientos.
- `v_saldosproductos`: stock actual, categoría, clase y marca.

## Alcance actual
- Estado del servicio.
- Búsqueda de productos para escáner.
- Búsqueda por código o nombre.
- Detalle de producto.
- Stock estimado por producto desde kardex.
- Historial de movimientos.
- Dataset base para scanner.
- Estadísticas básicas de catálogo.
- Consulta de saldos actuales desde `v_saldosproductos`.
- Filtro por clase de producto: desinfectante, cloro, frutas, verduras, snacks, sodas, etc.
- Filtro por categoría.

## Instalación
```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Edita `.env` y coloca la contraseña real si cambia.

## Ejecución
```bash
python run.py
```

También puedes ejecutar:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints existentes de productos/kardex
- `GET /api/health`
- `GET /api/productos/resumen`
- `GET /api/productos/dataset-scanner`
- `GET /api/productos/buscar?texto=adaptador`
- `GET /api/productos/escanear/4897103881980`
- `GET /api/productos/4897103881980/detalle`
- `GET /api/productos/4897103881980/stock`
- `GET /api/productos/4897103881980/historial`

## Nuevos endpoints de saldos
- `GET /api/saldos/health`
- `GET /api/saldos/columnas`
- `GET /api/saldos/resumen`
- `GET /api/saldos/dataset?limit=100`
- `GET /api/saldos/buscar?texto=pan&limit=20`
- `GET /api/saldos/buscar?texto=cloro&clase=Cloro&limit=20`
- `GET /api/saldos/clases`
- `GET /api/saldos/categorias`
- `GET /api/saldos/clase/Snacks?limit=50`
- `GET /api/saldos/producto/5442`

## Recomendación de prueba
Primero ejecuta:

```text
GET /api/saldos/columnas
```

Con eso validas que los nombres reales de las columnas sean `Codigo`, `Nombre`, `Stock`, `Marca`, `Categoria` y `Clase`. Si la vista usa nombres distintos, solo hay que ajustar `app/repositories/saldo_repository.py`.

## Diseño técnico
El backend no duplica la base de datos. Consulta directamente las vistas remotas y expone respuestas JSON listas para ser consumidas por la app Flutter.

## Notas
- Sin autenticación por ahora.
- Sin módulo de impresión por ahora.
- La API incluye cache en memoria opcional para reducir carga repetitiva.
=======
# ferrotienda_flutter_proyecto

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
>>>>>>> bddea29 (first commit)
# Wayner
