/*
 * ============================================================================
 * CONSULTA: titulos de predios rusticos
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : TÍTULOS DE PREDIOS RÚSTICOS
 * Qué responde        : Cartera de predios rústicos en el último corte. El saldo es el total de la planilla para estados D, N y DC; es cero para P (pagada) y X (anulada). Incluye paso de diagnóstico, opción A (sábana) y opción B (esquema estrella) con DAX sugerido.
 * Bases de origen     : RUSTICO_DM
 * Granularidad        : Una fila por predio y año
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Antes de ejecutar: sustituir <servidor> por el servidor del data warehouse.
 * ============================================================================
 */

/* =====================================================================
   CARTERA PREDIOS RUSTICOS  |  Base: RUSTICO_DM
   Servidor: <servidor>  |  Power BI > Import
   Grano   : 1 fila por IdFactPrediosRusticos (predio x Anio) en el ultimo corte
   Supuestos (validar con el PASO 0):
     SaldoPendiente = TotalPlanilla si el estado es D o N (ambos DEUDA) o DC (CONVENIO);
                      0 si P (pagada) o X (anulada). Codigos confirmados en RUSTICO_DM.
     FechaPago NO se usa para el saldo (en otras bases no era confiable).
     Antiguedad en anios = anio del corte - Anio (no hay fecha de exigibilidad).
   ===================================================================== */

/* =====================================================================
   PASO 0. DIAGNOSTICO (ejecutar primero)
   ===================================================================== */
-- USE RUSTICO_DM;
-- DECLARE @c int = (SELECT TOP (1) IdDimFechaCorte FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC);
-- SELECT d.IdEstadoDeuda, d.EstadoDeuda,
--        COUNT(*)                                                 AS Registros,
--        SUM(CASE WHEN f.FechaPago IS NULL THEN 1 ELSE 0 END)     AS SinFechaPago,
--        SUM(CASE WHEN f.FechaPago IS NOT NULL THEN 1 ELSE 0 END) AS ConFechaPago,
--        SUM(CASE WHEN f.Cuic IS NOT NULL THEN 1 ELSE 0 END)      AS ConCuic,
--        SUM(f.TotalPlanilla)                                     AS TotalPlanilla,
--        MIN(f.Anio) AS AnioMin, MAX(f.Anio) AS AnioMax
-- FROM dbo.FactPrediosRusticos f
-- LEFT JOIN dbo.DimEstadoDeuda d ON d.IdDimEstadoDeuda = f.IdDimEstadoDeuda
-- WHERE f.IdDimFechaCorte = @c
-- GROUP BY d.IdEstadoDeuda, d.EstadoDeuda ORDER BY d.IdEstadoDeuda;

/* =====================================================================
   OPCION A. SABANA COMPLETA
   Power BI > SQL Server > servidor + base RUSTICO_DM > Opciones avanzadas
   ===================================================================== */
SELECT
    f.IdFactPrediosRusticos                          AS IdFact,
    CAST(uc.FechaCorte AS date)                      AS FechaCorte,
    f.Anio                                           AS Anio,
    f.Cuic                                           AS Cuic,
    ded.IdEstadoDeuda, ded.EstadoDeuda,

    dn.RazonSocial                                   AS Contribuyente,

    dp.IDPREDIAL, dp.REG_CATASTRAL, dp.CODIGO_URBANO,
    dp.SECTOR, dp.MANZANA, dp.LOTE, dp.DIVISION, dp.PHV, dp.PHH,
    dp.DIRECCION, dp.Ubicacion,
    dz.Parroquia,
    f.Area, f.Avaluocom AS AvaluoComercial, f.Tarifa,

    dc.TieneConvenio, dc.TipoConvenio, dc.AnioConvenio, dc.NumeroConvenio,
    dc.FechaSuscripcion, dc.NumeroDividendos, dc.ValorCuotaInicial,
    dc.ConvenioAlDia, dc.FechaUltimoPago AS FechaUltimoPagoConvenio, dc.EsManual,

    dj.TieneJuicio, dj.Juicio, dj.Juzgado, dj.EstadoJuicio,
    CAST(dj.FechaIngresoJuicio  AS date)             AS FechaIngresoJuicio,
    CAST(dj.FechaInicioCoactiva AS date)             AS FechaInicioCoactiva,
    CAST(dj.FechaCitacionJuicio AS date)             AS FechaCitacionJuicio,

    dte.TipoExoneracion, f.PorcentajeAExonerar,
    f.AnioExpediente, f.NumeroExpediente, f.AnioResolucion, f.NumeroResolucion,
    dsol.Identificacion AS IdentificacionSolicitante, dsol.Solicitante,

    f.Rubro01ImpPredial                              AS Rubro01_ImpPredial,
    f.RUBRO02SALUDPECUARIA                           AS Rubro02_SaludPecuaria,
    f.RUBRO03IMPUESTOMI                              AS Rubro03_ImpuestoMI,
    f.Rubro04Bomberos                                AS Rubro04_Bomberos,
    f.RubrosXXOtros                                  AS RubrosOtros,
    f.TotalPlanilla                                  AS TotalPlanilla,

    CAST(CASE WHEN ded.IdEstadoDeuda IN ('D','N','DC') THEN f.TotalPlanilla ELSE 0 END
         AS decimal(38,2))                           AS SaldoPendiente,
    CAST(CASE WHEN ded.IdEstadoDeuda IN ('D','N','DC') AND f.Anio <= YEAR(uc.FechaCorte)
              THEN f.TotalPlanilla ELSE 0 END
         AS decimal(38,2))                           AS SaldoExigible,
    CAST(CASE WHEN f.Anio <= YEAR(uc.FechaCorte) THEN 1 ELSE 0 END AS bit) AS EsExigible,

    f.MiniAnioViegenciaEmitido                       AS MinAnioVigenciaEmitido,
    f.MiniAnioVigenciaPagado                         AS MinAnioVigenciaPagado,
    CAST(f.MiniFechaPago AS date)                    AS MinFechaPago,
    CAST(f.FechaPago     AS date)                    AS FechaPago,

    CASE WHEN f.Anio > YEAR(uc.FechaCorte) THEN NULL
         ELSE YEAR(uc.FechaCorte) - f.Anio END       AS AniosAntiguedad,
    CASE WHEN ded.IdEstadoDeuda = 'P'                       THEN '0. Pagado'
         WHEN ded.IdEstadoDeuda = 'X'                       THEN '0. Anulado'
         WHEN f.Anio >  YEAR(uc.FechaCorte)                 THEN '6. No exigible aun'
         WHEN f.Anio =  YEAR(uc.FechaCorte)                 THEN '1. Anio vigente'
         WHEN YEAR(uc.FechaCorte) - f.Anio = 1              THEN '2. 1 anio'
         WHEN YEAR(uc.FechaCorte) - f.Anio = 2              THEN '3. 2 anios'
         WHEN YEAR(uc.FechaCorte) - f.Anio <= 5             THEN '4. 3 a 5 anios'
         ELSE '5. Mas de 5 anios'
    END                                              AS RangoAntiguedad
FROM dbo.FactPrediosRusticos       AS f
JOIN (SELECT TOP (1) IdDimFechaCorte, FechaCorte
      FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC) AS uc ON uc.IdDimFechaCorte = f.IdDimFechaCorte
LEFT JOIN dbo.DimEstadoDeuda       AS ded  ON ded.IdDimEstadoDeuda    = f.IdDimEstadoDeuda
LEFT JOIN dbo.DimNombre            AS dn   ON dn.IdDimNombre          = f.IdDimNombre
LEFT JOIN dbo.DimPredio            AS dp   ON dp.IdDimPredio          = f.IdDimPredio
LEFT JOIN dbo.DimZona              AS dz   ON dz.IdDimZona            = f.IdDimZona
LEFT JOIN dbo.DimConvenio          AS dc   ON dc.IdDimConvenio        = f.IdDimConvenio
LEFT JOIN dbo.DimJuicioCoactivo    AS dj   ON dj.IdDimJucioCoactivo   = f.IdDimJucioCoactivo
LEFT JOIN dbo.DimTipoExoneracion   AS dte  ON dte.IdDimTipoExoneracion = f.IdDimTipoExoneracion
LEFT JOIN dbo.DimSolicitante       AS dsol ON dsol.IdDimSolicitante   = f.IdDimSolicitante;

/* =====================================================================
   OPCION B. ESQUEMA ESTRELLA (8 consultas, mas liviano)
   Relaciones muchos a uno: FactPrediosRusticos[IdDim...] -> Dim[IdDim...]
   ===================================================================== */

/* ---- B1) FactPrediosRusticos ----
SELECT f.IdFactPrediosRusticos AS IdFact, f.IdDimPredio, f.IdDimEstadoDeuda, f.IdDimZona,
       f.IdDimNombre, f.IdDimConvenio, f.IdDimJucioCoactivo, f.IdDimTipoExoneracion, f.IdDimSolicitante,
       f.Anio, f.Cuic, f.Area, f.Avaluocom AS AvaluoComercial, f.Tarifa, f.PorcentajeAExonerar,
       f.AnioExpediente, f.NumeroExpediente, f.AnioResolucion, f.NumeroResolucion,
       f.Rubro01ImpPredial AS Rubro01_ImpPredial, f.RUBRO02SALUDPECUARIA AS Rubro02_SaludPecuaria,
       f.RUBRO03IMPUESTOMI AS Rubro03_ImpuestoMI, f.Rubro04Bomberos AS Rubro04_Bomberos,
       f.RubrosXXOtros AS RubrosOtros, f.TotalPlanilla,
       CAST(CASE WHEN ded.IdEstadoDeuda IN ('D','N','DC') THEN f.TotalPlanilla ELSE 0 END AS decimal(38,2)) AS SaldoPendiente,
       CAST(CASE WHEN ded.IdEstadoDeuda IN ('D','N','DC') AND f.Anio <= YEAR(uc.FechaCorte) THEN f.TotalPlanilla ELSE 0 END AS decimal(38,2)) AS SaldoExigible,
       CAST(f.FechaPago AS date) AS FechaPago, CAST(uc.FechaCorte AS date) AS FechaCorte
FROM dbo.FactPrediosRusticos f
JOIN (SELECT TOP (1) IdDimFechaCorte, FechaCorte FROM dbo.DimFechaCorte ORDER BY FechaCorte DESC) uc
  ON uc.IdDimFechaCorte = f.IdDimFechaCorte
LEFT JOIN dbo.DimEstadoDeuda ded ON ded.IdDimEstadoDeuda = f.IdDimEstadoDeuda;

   ---- B2) DimNombre ----      SELECT IdDimNombre, RazonSocial AS Contribuyente FROM dbo.DimNombre;
   ---- B3) DimPredio ----      SELECT IdDimPredio, IDPREDIAL, REG_CATASTRAL, CODIGO_URBANO, SECTOR, MANZANA, LOTE, DIVISION, PHV, PHH, DIRECCION, Ubicacion FROM dbo.DimPredio;
   ---- B4) DimZona ----        SELECT IdDimZona, Parroquia FROM dbo.DimZona;
   ---- B5) DimEstadoDeuda ---- SELECT IdDimEstadoDeuda, IdEstadoDeuda, EstadoDeuda FROM dbo.DimEstadoDeuda;
   ---- B6) DimConvenio ----    SELECT * FROM dbo.DimConvenio;
   ---- B7) DimJuicioCoactivo - SELECT IdDimJucioCoactivo, TieneJuicio, Juicio, Juzgado, EstadoJuicio,
                                      CAST(FechaIngresoJuicio AS date) FechaIngresoJuicio,
                                      CAST(FechaInicioCoactiva AS date) FechaInicioCoactiva,
                                      CAST(FechaCitacionJuicio AS date) FechaCitacionJuicio FROM dbo.DimJuicioCoactivo;
   ---- B8) DimTipoExoneracion + DimSolicitante ----
        SELECT IdDimTipoExoneracion, TipoExoneracion FROM dbo.DimTipoExoneracion;
        SELECT IdDimSolicitante, Identificacion, Solicitante FROM dbo.DimSolicitante;
*/

/* ---- DAX sugerido ----
   Saldo Cartera   = SUM(FactPrediosRusticos[SaldoPendiente])
   Saldo Exigible  = SUM(FactPrediosRusticos[SaldoExigible])
   Total Emitido   = SUM(FactPrediosRusticos[TotalPlanilla])
   Predios con Saldo = CALCULATE(DISTINCTCOUNT(DimPredio[IDPREDIAL]), FactPrediosRusticos[SaldoPendiente] > 0)
   Area Total      = SUM(FactPrediosRusticos[Area])
*/
