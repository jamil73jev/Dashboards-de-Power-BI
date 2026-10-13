/*
 * ============================================================================
 * CONSULTA: titulos de cem
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : TÍTULOS DE CEM
 * Qué responde        : Sábana de la cartera de títulos de CEM por predio y año de deuda, en el último corte. Excluye años futuros. Saldo = valor CEM menos valor pagado (mínimo 0).
 * Bases de origen     : CEM_DM
 * Granularidad        : Una fila por predio y año de deuda
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Antes de ejecutar: sustituir <servidor> por el servidor del data warehouse.
 * ============================================================================
 */

/* =====================================================================
   SABANA COMPLETA - CARTERA DE TITULOS CEM
   Base    : CEM_DM  |  Servidor: <servidor>
   Uso     : Power BI > SQL Server > Opciones avanzadas > pegar este SELECT
   Grano   : 1 fila por predio y anio de deuda, en el ultimo corte
   Excluye : anios futuros (proyecciones) -> AnioDeuda > anio del corte
   Saldo   : ValorCem - ValorPagado (minimo 0)
   ===================================================================== */
SELECT
    /* ---------- Corte y llaves ---------- */
    f.IdFactPlanillaCEM                              AS IdFact,
    CAST(uc.FechaCorte AS date)                      AS FechaCorte,
    f.Cuic                                           AS Cuic,

    /* ---------- Titulo de credito ---------- */
    dt.TituloCredito                                 AS TituloCredito,
    f.AnioDeuda                                      AS AnioDeuda,
    f.AnioVigencia                                   AS AnioVigencia,
    f.Marca                                          AS Marca,
    ded.EstadoDeuda                                  AS EstadoDeuda,

    /* ---------- Contribuyente ---------- */
    dn.Nombre                                        AS Contribuyente,

    /* ---------- Predio ---------- */
    dp.IdPredio                                      AS IdPredio,
    dp.CodigoPredial                                 AS CodigoPredial,
    dp.Sector, dp.Manzana, dp.Lote, dp.Division,
    dp.Phv, dp.Phh, dp.Numero,
    dp.Latitud, dp.Longitud,
    dtp.TipoPredio                                   AS TipoPredio,
    f.ClasificacionCatastro                          AS ClasificacionCatastro,

    /* ---------- Zona ---------- */
    dz.IdCiudadela, dz.NombreCiudadela,
    dz.IdDistrito, dz.IdZonaHomogenea, dz.Direccion,

    /* ---------- Convenio ---------- */
    dc.TieneConvenio, dc.TipoConvenio, dc.AnioConvenio, dc.NumeroConvenio,
    dc.FechaSuscripcion, dc.NumeroDividendos, dc.ValorCuotaInicial,
    dc.ConvenioAlDia, dc.FechaUltimoPago AS FechaUltimoPagoConvenio, dc.EsManual,

    /* ---------- Avaluos y tarifa ---------- */
    f.AvaluoSolar, f.AvaluoEdificacion, f.AvaluoPropiedad,
    f.TarifaCem, f.MontoCemBase, f.PorcentajeExoneracion,

    /* ---------- Importes ---------- */
    f.ValorCem                                       AS ValorCem,
    f.ValorPagado                                    AS ValorPagado,
    CAST(CASE WHEN f.ValorCem - ISNULL(f.ValorPagado, 0) > 0
              THEN f.ValorCem - ISNULL(f.ValorPagado, 0) ELSE 0 END
         AS decimal(18,2))                           AS SaldoPendiente,
    CAST(f.FechaPago AS date)                        AS FechaPago,

    /* ---------- Antiguedad ---------- */
    YEAR(uc.FechaCorte) - f.AnioDeuda                AS AniosAntiguedad,
    CASE WHEN f.ValorCem - ISNULL(f.ValorPagado, 0) <= 0 THEN '0. Sin saldo'
         WHEN YEAR(uc.FechaCorte) - f.AnioDeuda <= 0     THEN '1. Anio vigente'
         WHEN YEAR(uc.FechaCorte) - f.AnioDeuda = 1      THEN '2. 1 anio'
         WHEN YEAR(uc.FechaCorte) - f.AnioDeuda = 2      THEN '3. 2 anios'
         WHEN YEAR(uc.FechaCorte) - f.AnioDeuda <= 5     THEN '4. 3 a 5 anios'
         ELSE '5. Mas de 5 anios'
    END                                              AS RangoAntiguedad
FROM PlanillaCEM.FactPlanillaCEM          AS f
JOIN (SELECT TOP (1) IdDimFechaCorte, FechaCorte
      FROM PlanillaCEM.DimFechaCorte
      ORDER BY FechaCorte DESC)           AS uc  ON uc.IdDimFechaCorte = f.IdDimFechaCorte
LEFT JOIN PlanillaCEM.DimTituloCredito    AS dt  ON dt.IdDimTituloCredito = f.IdDimTituloCredito
LEFT JOIN PlanillaCEM.DimNombre           AS dn  ON dn.IdDimNombre        = f.IdDimNombre
LEFT JOIN PlanillaCEM.DimPredio           AS dp  ON dp.IdDimPredio        = f.IdDimPredio
LEFT JOIN PlanillaCEM.DimTipoPredio       AS dtp ON dtp.IdDimTipoPredio   = f.IdDimTipoPredio
LEFT JOIN PlanillaCEM.DimZona             AS dz  ON dz.IdDimZona          = f.IdDimZona
LEFT JOIN PlanillaCEM.DimEstadoDeuda      AS ded ON ded.IdDimEstadoDeuda  = f.IdDimEstadoDeuda
LEFT JOIN PlanillaCEM.DimConvenio         AS dc  ON dc.IdDimConvenio      = f.IdDimConvenio
WHERE f.AnioDeuda <= YEAR(uc.FechaCorte);   -- excluye proyecciones 2027+
