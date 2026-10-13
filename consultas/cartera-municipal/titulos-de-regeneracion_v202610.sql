/*
 * ============================================================================
 * CONSULTA: titulos de regeneracion
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : TÍTULOS REGENERACIÓN
 * Qué responde        : Cartera de regeneración en el último corte: valor total, saldo pendiente y días de mora. Incluye paso de diagnóstico, opción A (sábana) y opción B (esquema estrella) con DAX sugerido. La llave del juicio se llama IdDimJucioCoativo porque así está escrita en la base.
 * Bases de origen     : REGENERACION_DM
 * Granularidad        : Una fila por deuda (IdFactRegeneracion)
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Antes de ejecutar: sustituir <servidor> por el servidor del data warehouse.
 * ============================================================================
 */

/* =====================================================================
   CARTERA REGENERACION  |  Base: REGENERACION_DM
   Servidor: <servidor>  |  Power BI > Import
   Grano   : 1 fila por IdFactRegeneracion (deuda) en el ultimo corte
   Supuestos (validar):
     ValorTotal     = ValorDeuda - ValorDescuento + ValorInteres + ValorMulta + ValorCoactiva
     SaldoPendiente = ValorTotal si FechaPago es NULL; 0 si ya se pago
     DiasMora       = dias desde FechaExigibilidad hasta la FechaCorte (solo con saldo)
   OJO: la llave del juicio se llama IdDimJucioCoativo (asi esta escrita en la base).
   ===================================================================== */

/* =====================================================================
   PASO 0. DIAGNOSTICO (ejecutar primero y revisar anios/estados)
   ===================================================================== */
-- USE REGENERACION_DM;
-- DECLARE @c int = (SELECT TOP (1) IdDimFechaCorte FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC);
-- SELECT f.AnioSolicitud, d.EstadoDeuda, COUNT(*) Registros,
--        SUM(f.ValorDeuda) ValorDeuda, SUM(f.ValorInteres) Interes, SUM(f.ValorCoactiva) Coactiva,
--        SUM(CASE WHEN f.FechaPago IS NOT NULL THEN 1 ELSE 0 END) ConFechaPago,
--        MIN(f.FechaExigibilidad) MinExig, MAX(f.FechaExigibilidad) MaxExig
-- FROM dbo.FactRegeneracion f
-- LEFT JOIN dbo.DimEstadoDeuda d ON d.IdDimEstadoDeuda = f.IdDimEstadoDeuda
-- WHERE f.IdDimFechaCorte = @c
-- GROUP BY f.AnioSolicitud, d.EstadoDeuda ORDER BY f.AnioSolicitud, d.EstadoDeuda;

/* =====================================================================
   OPCION A. SABANA COMPLETA (una sola consulta)
   Power BI > SQL Server > servidor + base REGENERACION_DM > Opciones avanzadas
   ===================================================================== */
SELECT
    f.IdFactRegeneracion                             AS IdFact,
    f.IdDeuda                                        AS IdDeuda,
    CAST(uc.FechaCorte AS date)                      AS FechaCorte,
    f.Cep, f.Cuic,
    f.AnioSolicitud, f.AnioVigenciaPredio,
    ded.IdEstadoDeuda, ded.EstadoDeuda,

    dct.Nombre                                       AS Contribuyente,

    dip.IdPredio, dip.CodigoCatastral,
    dip.Sector, dip.Manzana, dip.Lote, dip.Division,
    dip.Phv, dip.Phh, dip.Numero,

    dc.TieneConvenio, dc.TipoConvenio, dc.AnioConvenio, dc.NumeroConvenio,
    dc.FechaSuscripcion, dc.NumeroDividendos, dc.ValorCuotaInicial,
    dc.ConvenioAlDia, dc.FechaUltimoPago AS FechaUltimoPagoConvenio, dc.EsManual,

    dj.TieneJuicio, dj.Juicio, dj.Juzgado, dj.EstadoJuicio,
    CAST(dj.FechaIngresoJuicio  AS date)             AS FechaIngresoJuicio,
    CAST(dj.FechaInicioCoactiva AS date)             AS FechaInicioCoactiva,
    CAST(dj.FechaCitacionJuicio AS date)             AS FechaCitacionJuicio,

    CAST(f.FechaVigenciaDesde AS date)               AS FechaVigenciaDesde,
    CAST(f.FechaVigenciaHasta AS date)               AS FechaVigenciaHasta,
    CAST(f.FechaExigibilidad  AS date)               AS FechaExigibilidad,
    CAST(f.FechaInteresDesde  AS date)               AS FechaInteresDesde,
    CAST(f.FechaCoactivaDesde AS date)               AS FechaCoactivaDesde,
    CAST(f.FechaPago          AS date)               AS FechaPago,

    f.ValorDeuda, f.ValorDescuento, f.ValorInteres, f.ValorMulta, f.ValorCoactiva,
    CAST(f.ValorDeuda - f.ValorDescuento + f.ValorInteres + f.ValorMulta + f.ValorCoactiva
         AS decimal(19,2))                           AS ValorTotal,
    CAST(CASE WHEN f.FechaPago IS NULL
              THEN f.ValorDeuda - f.ValorDescuento + f.ValorInteres + f.ValorMulta + f.ValorCoactiva
              ELSE 0 END AS decimal(19,2))           AS SaldoPendiente,

    CASE WHEN f.FechaPago IS NULL AND f.FechaExigibilidad <= uc.FechaCorte
         THEN DATEDIFF(DAY, f.FechaExigibilidad, uc.FechaCorte) END AS DiasMora,
    CASE WHEN f.FechaPago IS NOT NULL                     THEN '0. Pagado'
         WHEN f.FechaExigibilidad IS NULL                 THEN '9. Sin fecha'
         WHEN f.FechaExigibilidad >  uc.FechaCorte        THEN '1. No exigible aun'
         WHEN DATEDIFF(DAY, f.FechaExigibilidad, uc.FechaCorte) <=  30 THEN '2. 1-30 dias'
         WHEN DATEDIFF(DAY, f.FechaExigibilidad, uc.FechaCorte) <=  90 THEN '3. 31-90 dias'
         WHEN DATEDIFF(DAY, f.FechaExigibilidad, uc.FechaCorte) <= 180 THEN '4. 91-180 dias'
         WHEN DATEDIFF(DAY, f.FechaExigibilidad, uc.FechaCorte) <= 365 THEN '5. 181-365 dias'
         ELSE '6. Mas de 1 anio'
    END                                              AS RangoMora
FROM dbo.FactRegeneracion          AS f
JOIN (SELECT TOP (1) IdDimFechaCorte, FechaCorte
      FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC) AS uc ON uc.IdDimFechaCorte = f.IdDimFechaCorte
LEFT JOIN dbo.DimEstadoDeuda       AS ded ON ded.IdDimEstadoDeuda   = f.IdDimEstadoDeuda
LEFT JOIN dbo.DimContribuyente     AS dct ON dct.IdDimContribuyente = f.IdDimContribuyente
LEFT JOIN dbo.DimInfoPredio        AS dip ON dip.IdDimInfoPredio    = f.IdDimInfoPredio
LEFT JOIN dbo.DimConvenio          AS dc  ON dc.IdDimConvenio       = f.IdDimConvenio
LEFT JOIN dbo.DimJuicioCoactivo    AS dj  ON dj.IdDimJucioCoativo   = f.IdDimJucioCoativo;

/* =====================================================================
   OPCION B. ESQUEMA ESTRELLA (6 consultas, mas liviano)
   Relaciones (muchos a uno): FactRegeneracion[IdDim...] -> Dim[IdDim...]
   ===================================================================== */

/* ---- B1) FactRegeneracion ----
SELECT f.IdFactRegeneracion AS IdFact, f.IdDeuda, f.Cep, f.Cuic,
       f.IdDimEstadoDeuda, f.IdDimConvenio, f.IdDimJucioCoativo,
       f.IdDimContribuyente, f.IdDimInfoPredio,
       f.AnioSolicitud, f.AnioVigenciaPredio,
       CAST(f.FechaExigibilidad AS date) AS FechaExigibilidad,
       CAST(f.FechaPago AS date)         AS FechaPago,
       CAST(uc.FechaCorte AS date)       AS FechaCorte,
       f.ValorDeuda, f.ValorDescuento, f.ValorInteres, f.ValorMulta, f.ValorCoactiva,
       CAST(f.ValorDeuda - f.ValorDescuento + f.ValorInteres + f.ValorMulta + f.ValorCoactiva AS decimal(19,2)) AS ValorTotal,
       CAST(CASE WHEN f.FechaPago IS NULL
                 THEN f.ValorDeuda - f.ValorDescuento + f.ValorInteres + f.ValorMulta + f.ValorCoactiva
                 ELSE 0 END AS decimal(19,2)) AS SaldoPendiente
FROM dbo.FactRegeneracion f
JOIN (SELECT TOP (1) IdDimFechaCorte, FechaCorte FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC) uc
  ON uc.IdDimFechaCorte = f.IdDimFechaCorte;

   ---- B2) DimContribuyente ----
SELECT IdDimContribuyente, Nombre AS Contribuyente FROM dbo.DimContribuyente;

   ---- B3) DimInfoPredio ----
SELECT IdDimInfoPredio, IdPredio, CodigoCatastral, Sector, Manzana, Lote, Division, Phv, Phh, Numero
FROM dbo.DimInfoPredio;

   ---- B4) DimEstadoDeuda ----
SELECT IdDimEstadoDeuda, IdEstadoDeuda, EstadoDeuda FROM dbo.DimEstadoDeuda;

   ---- B5) DimConvenio ----
SELECT IdDimConvenio, TieneConvenio, TipoConvenio, AnioConvenio, NumeroConvenio, FechaSuscripcion,
       NumeroDividendos, ValorCuotaInicial, ConvenioAlDia, FechaUltimoPago AS FechaUltimoPagoConvenio, EsManual
FROM dbo.DimConvenio;

   ---- B6) DimJuicioCoactivo ----
SELECT IdDimJucioCoativo, TieneJuicio, Juicio, Juzgado, EstadoJuicio,
       CAST(FechaIngresoJuicio AS date) AS FechaIngresoJuicio,
       CAST(FechaInicioCoactiva AS date) AS FechaInicioCoactiva,
       CAST(FechaCitacionJuicio AS date) AS FechaCitacionJuicio
FROM dbo.DimJuicioCoactivo;
*/

/* ---- DAX sugerido ----
   Saldo Cartera   = SUM(FactRegeneracion[SaldoPendiente])
   Valor Total     = SUM(FactRegeneracion[ValorTotal])
   Deudas          = DISTINCTCOUNT(FactRegeneracion[IdDeuda])
   Deudas con Saldo= CALCULATE(DISTINCTCOUNT(FactRegeneracion[IdDeuda]), FactRegeneracion[SaldoPendiente] > 0)
   En Coactiva     = CALCULATE(SUM(FactRegeneracion[SaldoPendiente]), DimJuicioCoactivo[TieneJuicio] = "SI")
*/
