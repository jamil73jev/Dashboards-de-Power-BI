# Terminal de Transferencia de Víveres: Control de Tickets y Recaudación

| Dato | Valor |
|---|---|
| Archivo | `Terminal de Transferencia de Víveres Control de Tickets y Recaudación.pbix` (279 MB) |
| Último cambio | septiembre 2026 |
| Contiene datos personales | No se observa |
| Fuente de datos | Base de datos municipal en un data warehouse |

## Páginas

La descripción se deduce del nombre de cada página y de sus visuales; falta validarla con el autor.

| Página | Visuales | Contenido (según el nombre de la página) |
|---|---|---|
| DASHBOARD | 1 visual HTML Content | Vista principal |
| RESUMEN | 7 segmentadores, 1 tarjeta, 2 gráficos de barras, 2 tablas dinámicas, 1 gráfico de líneas | Recaudación por caja y equipo, mapa de calor por día y hora |
| TICKETS NO PAGADOS | 7 segmentadores, 1 tarjeta, 1 línea, 1 tabla, 2 gráficos de barras/columnas | Tickets sin cobrar |
| ANÁLISIS DE TICKETS | 3 segmentadores, 1 tabla, 1 tarjeta, 1 filtro de texto | Análisis por ticket |
| SERIE DE TICKETS | 3 segmentadores, 1 tabla, 1 tarjeta, 1 filtro de texto | Series de numeración |

El nombre de la página `ANALISIS DE TICKTS` tiene un error ortográfico en el archivo.

Visuales personalizados: HTML Content, filtro de texto.

## Consultas

Consultas SQL que cargan los datos de este dashboard. Índice completo en [`consultas/`](../consultas/README.md).

| Página | Consulta |
|---|---|
| DASHBOARD, RESUMEN y TICKETS NO PAGADOS | [`ttv-eventos-de-caja-tickets-sin-pago-y-abonados_v202610.sql`](../consultas/terminal-de-transferencia-de-viveres/ttv-eventos-de-caja-tickets-sin-pago-y-abonados_v202610.sql) |

## Por documentar
- Frecuencia de actualización.
- Usuarios con acceso.
