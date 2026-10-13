# Recaudación Municipal: Tablero Ejecutivo

| Dato | Valor |
|---|---|
| Archivo | `Recaudación Municipal Tablero Ejecutivo.pbix` (183 MB) |
| Último cambio | octubre 2026 |
| Contiene datos personales | Por confirmar (parece agregado) |
| Fuente de datos | Base de datos municipal en un data warehouse |

## Páginas

La descripción se deduce del nombre de cada página y de sus visuales; falta validarla con el autor.

| Página | Visuales | Contenido (según el nombre de la página) |
|---|---|---|
| DESGLOSE POR CAJERO | 1 tabla dinámica, 1 árbol de descomposición | Recaudación por cajero |
| DESGLOSE | 1 tabla dinámica, 1 visual Inforiver | Recaudación por categoría |
| PRINCIPAL | 1 tabla dinámica, 1 visual Inforiver | Vista ejecutiva |
| RUBROS | 1 visual Inforiver | Recaudación por rubro |
| PUNTOS DE RECAUDACIÓN | 2 visuales Inforiver | Recaudación por punto |
| NO TRIBUTARIO | 1 tabla dinámica, 1 visual Inforiver | Ingresos no tributarios |
| RESOLUCIONES | 1 visual Inforiver | Resoluciones |
| COACTIVA | 1 árbol de descomposición, 1 tabla dinámica, 1 visual Inforiver | Recaudación por coactiva |
| GEORREFERENCIACIÓN | 1 visual HTML Content, 1 tabla dinámica | Panel HTML de contribuyentes por tipo de deuda, título, juicio y sector. Documentada en [PIGGC](https://github.com/jamil73jev/Geospatial-Debt-Analytics-Platform) |

Los nombres de página del archivo tienen errores ortográficos (`DESGLOCE`, `RECAUDADCION`); conviene corregirlos en el `.pbix`.

Visuales personalizados: Inforiver, HTML Content.

## Consultas

Consultas SQL que cargan los datos de este dashboard. Índice completo en [`consultas/`](../consultas/README.md).

| Página | Consulta |
|---|---|
| COACTIVA | [`recaudacion-coactiva_v202610.sql`](../consultas/recaudacion-municipal/recaudacion-coactiva_v202610.sql) |
| PRINCIPAL y DESGLOSE | [`recaudacion-gerencial-hibrida-2023-2026_v202610.sql`](../consultas/recaudacion-municipal/recaudacion-gerencial-hibrida-2023-2026_v202610.sql) |
| RUBROS y NO TRIBUTARIO | [`recaudacion-por-rubros_v202610.sql`](../consultas/recaudacion-municipal/recaudacion-por-rubros_v202610.sql) |
| DESGLOSE POR CAJERO | [`recaudacion-auditoria-por-cajero_v202610.sql`](../consultas/recaudacion-municipal/recaudacion-auditoria-por-cajero_v202610.sql) |
| PUNTOS DE RECAUDACIÓN | [`recaudacion-por-puntos-de-recaudacion_v202610.sql`](../consultas/recaudacion-municipal/recaudacion-por-puntos-de-recaudacion_v202610.sql) |

## Por documentar
- Frecuencia de actualización.
- Usuarios con acceso.
