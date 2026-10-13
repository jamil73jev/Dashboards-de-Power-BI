# Cartera Municipal: Cobranza y Conciliación

| Dato | Valor |
|---|---|
| Archivo | `Cartera Municipal Cobranza y Conciliación.pbix` (457 MB) |
| Último cambio | octubre 2026 |
| Contiene datos personales | Sí: RUC, nombre y código predial |
| Fuente de datos | Base de datos municipal en un data warehouse |
| Mapa | La página CARTERA incluye un mapa ArcGIS con la ubicación de contribuyentes |

## Páginas

La descripción se deduce del nombre de cada página y de sus visuales; falta validarla con el autor.

| Página | Visuales | Contenido (según el nombre de la página) |
|---|---|---|
| CARTERA | 4 segmentadores, 1 tarjeta, 1 tabla, 1 mapa ArcGIS, 1 filtro de texto | Cartera de 1,5‰ y patente, con ubicación de contribuyentes |
| CONCILIACIÓN DE CARTERA | 1 tabla, 1 filtro de texto | Cuadre de cartera contra la fuente |
| TÍTULOS DE CRÉDITO | 2 tablas, 3 segmentadores, 1 tarjeta | Detalle de títulos de crédito |
| TÍTULOS DE PREDIOS | 1 tabla, 1 segmentador, 3 tarjetas, 2 filtros de texto | Títulos de predios |
| TÍTULOS DE CEM | 1 tabla, 1 segmentador, 3 tarjetas, 2 filtros de texto | Títulos de CEM |
| TÍTULOS DE PREDIOS RÚSTICOS | 1 tabla, 1 segmentador, 3 tarjetas, 2 filtros de texto | Títulos de predios rústicos |
| TÍTULOS REGENERACIÓN | 1 tabla, 1 segmentador, 3 tarjetas, 2 filtros de texto | Títulos de regeneración urbana |

Visuales personalizados: mapa Esri (ArcGIS), filtro de texto.

## Consultas

Consultas SQL que cargan los datos de este dashboard. Índice completo en [`consultas/`](../consultas/README.md).

| Página | Consulta |
|---|---|
| CARTERA (base de la página GEORREFERENCIACIÓN de SICOGE) | [`cartera-consolidada_v202610.sql`](../consultas/cartera-municipal/cartera-consolidada_v202610.sql) |
| TÍTULOS DE CRÉDITO | [`titulos-sabana-de-trazabilidad-por-juicio_v202610.sql`](../consultas/cartera-municipal/titulos-sabana-de-trazabilidad-por-juicio_v202610.sql) |
| CONCILIACIÓN DE CARTERA y TÍTULOS DE CRÉDITO | [`titulos-sabana-de-conciliacion_v202610.sql`](../consultas/cartera-municipal/titulos-sabana-de-conciliacion_v202610.sql) |
| TÍTULOS DE PREDIOS | [`titulos-de-predios-urbanos_v202610.sql`](../consultas/cartera-municipal/titulos-de-predios-urbanos_v202610.sql) |
| TÍTULOS DE CEM | [`titulos-de-cem_v202610.sql`](../consultas/cartera-municipal/titulos-de-cem_v202610.sql) |
| TÍTULOS DE PREDIOS RÚSTICOS | [`titulos-de-predios-rusticos_v202610.sql`](../consultas/cartera-municipal/titulos-de-predios-rusticos_v202610.sql) |
| TÍTULOS REGENERACIÓN | [`titulos-de-regeneracion_v202610.sql`](../consultas/cartera-municipal/titulos-de-regeneracion_v202610.sql) |

## Por documentar
- Frecuencia de actualización.
- Usuarios con acceso.
