# Dashboards de Power BI: fichas e inventario

**Autor y responsable:** Jorge Jamil Espinoza Villa, Analista Financiero
**Área:** Dirección General Financiera, M.I. Municipalidad de Guayaquil

Este repositorio **solo documenta** los dashboards. Los archivos `.pbix` no se suben a GitHub porque pesan entre 183 y 457 MB (el límite de GitHub es 100 MB) y llevan los datos importados dentro. Se guardan en el almacenamiento institucional.

## Inventario

| Dashboard | Archivo | Tamaño | Último cambio | Datos personales |
|---|---|---|---|---|
| Cartera Municipal: Cobranza y Conciliación | `Cartera Municipal Cobranza y Conciliación.pbix` | 457 MB | oct 2026 | Sí: RUC, nombre y código predial |
| Recaudación Municipal: Tablero Ejecutivo | `Recaudación Municipal Tablero Ejecutivo.pbix` | 183 MB | oct 2026 | Por confirmar (parece agregado) |
| Facturación y Recaudación TRB, Interagua 2025 | `Facturación y Recaudación TRB, Interagua 2025.pbix` | 288 MB | feb 2026 | Por confirmar (nombres de clientes) |
| Terminal de Transferencia de Víveres: Control de Tickets y Recaudación | `Terminal de Transferencia de Víveres Control de Tickets y Recaudación.pbix` | 279 MB | sep 2026 | No se observa |

## Fichas

### Cartera Municipal: Cobranza y Conciliación
Siete páginas: Cartera (1,5‰ y patente, con mapa de SICOGE), Conciliación de Cartera, Títulos de Crédito, Títulos de Predios, Títulos de CEM, Títulos de Predios Rústicos y Títulos Regeneración. Filtros por contribuyente, año de título y fecha de corte. Usa visuales personalizados (Inforiver, HTML Content, Text Filter).

### Recaudación Municipal: Tablero Ejecutivo
Nueve páginas: Desglose por Cajero, Desglose, Principal, Rubros, Puntos de Recaudación, No Tributario, Resoluciones, Coactiva y Georreferenciación. Usa Inforiver, árbol de descomposición, tablas dinámicas y mapa de iconos.

### Facturación y Recaudación TRB, Interagua 2025
Cinco páginas: Análisis Temporal, Perfiles de Pago, Resumen Financiero, Facturación vs Recaudación y Gestión de Recaudación (enero a septiembre 2025). Publicado en el servicio de Power BI.

### Terminal de Transferencia de Víveres: Control de Tickets y Recaudación
Cinco páginas: Dashboard (HTML), Resumen (recaudación por caja y equipo, mapa de calor por día y hora), Tickets No Pagados, Análisis de Tickets y Serie de Tickets.

## Convención de nombres

`tema_vAAAAMM.pbix` para el archivo guardado en el almacenamiento institucional, con la fecha del último cambio de contenido.

## Pendiente por documentar

- [ ] Fuente de datos de cada dashboard (base, Excel o carpeta) y frecuencia de actualización.
- [ ] Responsable y usuarios con acceso.
- [ ] Significado de la sigla TRB.
