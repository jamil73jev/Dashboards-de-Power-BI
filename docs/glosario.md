# Glosario

Términos y siglas que aparecen en los dashboards, las fichas y las consultas. Lo marcado como **por confirmar** no está definido en ningún documento fuente y no se debe usar como definición oficial.

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
| Pareto | Orden de los contribuyentes por deuda para ver cuántos concentran el 80 %, 90 %, 95 % y 99 % de la cartera. Ver [SICOGE](https://github.com/jamil73jev/SICOGE/blob/main/docs/segmentacion-y-calidad-de-ubicacion.md) |
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
| SIGECO | Sistema Integral de Gestión de Cobranza |
| SICOGE | Gestión de Cartera Basada en Análisis Geoespacial |
| CEM | **Por confirmar** |
| CEP | **Por confirmar** (aparece como código en la instancia Bahías de SIGECO) |
| SPI | **Por confirmar** (aparece como tipo de transferencia en la recaudación por cajero) |
| AGA | **Por confirmar** (campo geográfico de la cartera consolidada) |
