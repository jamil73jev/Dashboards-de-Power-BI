# Glosario

Términos y siglas que aparecen en los dashboards, las fichas y las consultas. Si una sigla no está confirmada, se marca como **por confirmar** y no se debe usar como definición oficial.

## Cobranza y cartera

| Término | Significado |
|---|---|
| Cartera | Conjunto de obligaciones que los contribuyentes tienen pendientes de pago |
| Obligación | Una deuda concreta de un contribuyente: un título, un juicio o un tipo de impuesto en un año |
| Título de crédito | Documento con el que la Municipalidad establece una deuda. En las consultas, fase `TIT` |
| Coactiva | Etapa de cobro por vía de juicio coactivo. En las consultas, fase `COA` |
| Juzgado | Los juicios coactivos se reparten en cuatro juzgados: primero, segundo, tercero y cuarto |
| Corte | Fecha a la que se toma una foto de la cartera. Casi todas las consultas usan el último corte disponible |
| Saldo pendiente | Valor que aún no se ha pagado de una obligación. Cada tipo de cartera lo calcula con su propia regla (ver el encabezado de cada consulta) |
| Pareto | Orden de los contribuyentes por deuda para ver cuántos concentran el 80 %, 90 %, 95 % y 99 % de la cartera. Ver [PIGGC](https://github.com/jamil73jev/Geospatial-Debt-Analytics-Platform/blob/main/docs/segmentacion-y-calidad-de-ubicacion.md) |
| Reverso | Anulación de un cobro. Resta de la recaudación bruta para dar la neta |

## Estados de cartera

| Estado | Significado | Tipo |
|---|---|---|
| `TIN` | Ingreso razón de no recepción de título de crédito | Títulos de crédito |
| `GAT` | Generación automática de título de crédito | Títulos de crédito |
| `P` | Sorteado | Coactiva |
| `T` | Autos impreso | Coactiva |

## Siglas

| Sigla | Significado |
|---|---|
| RUC | Registro Único de Contribuyentes |
| TRB | Tasa de Recolección de Basura |
| TTV | Terminal de Transferencia de Víveres |
| DM | *Data mart*: base temática del data warehouse (por ejemplo `RECAUDACION_DM`) |
| Fact y Dim | Tablas de hechos y de dimensiones de un data mart (`FactCobro`, `DimFechaCorte`) |
| 15PORMIL | Impuesto del 1,5 por mil |
| SIGCC | Sistema Integral de Gestión y Control de Cobranzas (antes SIGECO) |
| PIGGC | Plataforma de Inteligencia Geoespacial para la Gestión de Cartera (antes SICOGE) |
| CEM | Contribución Especial de Mejora |
| CEP | Código Electrónico de Pago. Aparece como código del puesto en la instancia Bahías de SIGCC y como campo en los títulos de regeneración |
| SPI | Sistema de Pagos Interbancarios. Aparece como tipo de transferencia en la recaudación por cajero |
| AGA | Áreas de Gestión Administrativa. Campo geográfico de la cartera consolidada |
| PHV | Propiedad horizontal vertical. Parte de la clave catastral |
| PHH | Propiedad horizontal horizontal. Parte de la clave catastral |
| Clave catastral | Combinación de `Sector`, `Manzana`, `Lote`, `Division`, `Phv` y `Phh` que identifica un predio en el catastro. De ella nace la ubicación geográfica de la deuda. Ver [PIGGC](https://github.com/jamil73jev/Geospatial-Debt-Analytics-Platform/blob/main/docs/segmentacion-y-calidad-de-ubicacion.md) |
