/*
 * ============================================================================
 * CONSULTA: titulos sabana de conciliacion
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : CONCILIACIÓN DE CARTERA y TÍTULOS DE CRÉDITO
 * Qué responde        : Versión de la sábana con una sola fila por título (conserva el juicio más reciente), para conciliar sin multiplicar el valor del título ni el valor total al cobro.
 * Bases de origen     : TITULOS_CREDITO_DM, COACTIVA_DM
 * Granularidad        : Una fila por título
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/* ============================================================
   POWER BI - SÁBANA ANALÍTICA DE TRAZABILIDAD
   TÍTULOS DE CRÉDITO + COACTIVA

   Estructura:
   - Mantiene nombres de columnas originales.
   - Una sola fila por título para conciliación financiera en Power BI.
   - Recupera todos los juicios asociados internamente y conserva únicamente
     el juicio más reciente de cada título.
   - Cruce principal auditado:
       1) Año título + Número título = llave de negocio para recuperar todos los juicios.
       2) IdDimJuicioCoactivo se usa como contraste/auditoría, NO como llave suficiente.
       3) Identificación se usa como control de calidad, NO como requisito de cruce.
   - Deduplica por título + IdDimJuicioCoactivo antes de elegir el último juicio.
   - Evita la multiplicación de ValorTitulo y ValorTotal_AlCobro.
   - Corrección de COLLATE.
   ============================================================ */

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdDimFechaCorte INT = NULL;
DECLARE @SoloCicloActivo BIT = 1;
DECLARE @SoloSinJuicio BIT = 0;

/* Si queda NULL, toma automáticamente el último corte disponible */
IF @IdDimFechaCorte IS NULL
BEGIN
    SELECT
        @IdDimFechaCorte = MAX(FVT.IdDimFechaCorte)
    FROM TITULOS_CREDITO_DM.dbo.FactValoresTitulo AS FVT;
END;

IF OBJECT_ID('tempdb..#TitulosBase') IS NOT NULL DROP TABLE #TitulosBase;
IF OBJECT_ID('tempdb..#CoactivaDirecta') IS NOT NULL DROP TABLE #CoactivaDirecta;
IF OBJECT_ID('tempdb..#CoactivaAlternativa') IS NOT NULL DROP TABLE #CoactivaAlternativa;
IF OBJECT_ID('tempdb..#CoactivaCandidata') IS NOT NULL DROP TABLE #CoactivaCandidata;
IF OBJECT_ID('tempdb..#CoactivaJuicios') IS NOT NULL DROP TABLE #CoactivaJuicios;
IF OBJECT_ID('tempdb..#DetalleCoactivaAgg') IS NOT NULL DROP TABLE #DetalleCoactivaAgg;


/* ============================================================
   1. BASE DE TÍTULOS
   ============================================================ */

SELECT
    CorteUsado = @IdDimFechaCorte,
    FC.FechaCorte,

    LlaveTituloCompleta =
        CONCAT(
            ISNULL(CONVERT(VARCHAR(10), IT.AnioTitulo), 'SIN_ANIO') COLLATE Latin1_General_CI_AI,
            '|' COLLATE Latin1_General_CI_AI,
            ISNULL(CONVERT(VARCHAR(50), IT.NumeroTitulo), 'SIN_TITULO') COLLATE Latin1_General_CI_AI,
            '|' COLLATE Latin1_General_CI_AI,
            ISNULL(
                NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(50), C.NumeroCiudadano))), ''),
                'SIN_IDENTIFICACION'
            ) COLLATE Latin1_General_CI_AI
        ),

    FVT.IdFactValoresTitulo,
    FVT.IdDimInfoTitulo,
    FVT.IdDimContribuyente,
    FVT.IdDimEstado,
    FVT.IdDimTipoDeuda,
    FVT.IdDimConvenio,
    FVT.IdDimJuicioCoactivo,
    FVT.IdDimJuicioCoactivoFechaCorte,

    IT.AnioTitulo,
    IT.NumeroTitulo,
    IT.IdSolicitud,
    IT.ConceptoDeuda,
    IT.DireccionTitulo,
    IT.FechaEmisionTitulo,
    IT.FechaNotificacionDate,
    IT.FechaExigibilidad,
    IT.FechaInteresDesde,
    IT.FechaCoactivaDesde,
    IT.FechaBaja,

    FI.FechaIngreso AS FechaIngresoTitulo,

    NumeroCiudadanoKey =
        NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(30), C.NumeroCiudadano))), '') COLLATE Latin1_General_CI_AI,

    C.NombreContribuyente,
    C.EstadoRegistroCivil,
    C.EstadoSRI,

    C.FechaFallecimiento,

    E.CodEstado,
    E.Estado AS EstadoTitulo,
    E.EstadoGeneral AS EstadoGeneralTitulo,

    TD.IdTipoDeuda,
    TD.TipoDeuda,
    TD.SubTipoDeuda,
    TD.Origen,
    TD.Categoria,
    TD.TipoDeudaBalance,
    TD.SubTipoDeudaBalance,

    CV.TieneConvenio AS TieneConvenioTitulo,
    CV.AnioConvenio AS AnioConvenioTitulo,
    CV.NumeroConvenio AS NumeroConvenioTitulo,
    CV.FechaSuscripcion AS FechaSuscripcionConvenioTitulo,
    CV.ConvenioAlDia AS ConvenioAlDiaTitulo,
    CV.FechaUltimoPago AS FechaUltimoPagoConvenioTitulo,
    CV.TipoConvenio,

    JFC.TieneJuicio AS TieneJuicioFechaCorte,
    JFC.Juicio AS JuicioFechaCorte,
    JFC.EstadoJuicio AS EstadoJuicioFechaCorte,
    JFC.Juzgado AS JuzgadoFechaCorte,

    FVT.CantidadTitulos,
    FVT.ValorTitulo,
    FVT.ValorDeuda,
    FVT.ValorTasa,
    FVT.ValorInteres,
    FVT.ValorMulta,
    FVT.ValorCoactiva,
    FVT.ValorDescuento,
    FVT.ValorConvenio,
    FVT.ValorTotal,

    FVT.ValorDeuda_AlCobro,
    FVT.ValorDescuento_AlCobro,
    FVT.ValorInteres_AlCobro,
    FVT.ValorMulta_AlCobro,
    FVT.ValorTasa_AlCobro,
    FVT.ValorRecargo_AlCobro,
    FVT.ValorCoactiva_AlCobro,
    FVT.ValorPagoConvenio_AlCobro,
    FVT.ValorTotal_AlCobro,

    CondicionJuicioTitulo =
        CASE
            WHEN UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
                 AND ISNULL(FVT.IdDimJuicioCoactivo, 0) = 0
                THEN 'EN COACTIVA SIN ID JUICIO EN TITULOS'

            WHEN UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
                 AND ISNULL(FVT.IdDimJuicioCoactivo, 0) > 0
                THEN 'EN COACTIVA CON ID JUICIO EN TITULOS'

            WHEN UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
                THEN 'EN PROCESO DE TITULO'

            ELSE 'OTRA CONDICION'
        END,

    EtapaInicialCiclo =
        CASE
            WHEN IT.FechaBaja IS NOT NULL
                THEN 'BAJA / ANULACION'

            WHEN C.FechaFallecimiento IS NOT NULL
                THEN 'CONTRIBUYENTE FALLECIDO'

            WHEN UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
              OR UPPER(LTRIM(RTRIM(E.Estado))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
                THEN 'DERIVADO A COACTIVA'

            WHEN UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
              OR UPPER(LTRIM(RTRIM(E.Estado))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
                THEN 'GESTION EN TITULO'

            ELSE 'OTRO ESTADO'
        END

INTO #TitulosBase

FROM TITULOS_CREDITO_DM.dbo.FactValoresTitulo AS FVT

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimFechaCorte AS FC
    ON FVT.IdDimFechaCorte = FC.IdDimFechaCorte

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimInfoTitulo AS IT
    ON FVT.IdDimInfoTitulo = IT.IdDimInfoTitulo

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimContribuyente AS C
    ON FVT.IdDimContribuyente = C.IdDimContribuyente

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimEstado AS E
    ON FVT.IdDimEstado = E.IdDimEstado

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimTipoDeuda AS TD
    ON FVT.IdDimTipoDeuda = TD.IdDimTipoDeuda

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimConvenio AS CV
    ON FVT.IdDimConvenio = CV.IdDimConvenio

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimFechaIngreso AS FI
    ON FVT.IdDimFechaIngreso = FI.IdDimFechaIngreso

LEFT JOIN TITULOS_CREDITO_DM.dbo.DimJuicioCoactivoFechaCorte AS JFC
    ON FVT.IdDimJuicioCoactivoFechaCorte = JFC.IdDimJuicioCoactivoFechaCorte
   AND FVT.IdDimFechaCorte = JFC.IdDimFechaCorte
   AND FVT.IdDimInfoTitulo = JFC.IdDimInfoTitulo

WHERE
    FVT.IdDimFechaCorte = @IdDimFechaCorte
    AND
    (
        @SoloCicloActivo = 0
        OR UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI = 'EN COACTIVA'
        OR UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
        OR UPPER(LTRIM(RTRIM(E.Estado))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
        OR UPPER(LTRIM(RTRIM(E.Estado))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
    )
    AND
    (
        @SoloSinJuicio = 0
        OR
        (
            (
                UPPER(LTRIM(RTRIM(E.EstadoGeneral))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
                OR UPPER(LTRIM(RTRIM(E.Estado))) COLLATE Latin1_General_CI_AI LIKE '%COACTIVA%'
            )
            AND ISNULL(FVT.IdDimJuicioCoactivo, 0) = 0
        )
    );


CREATE CLUSTERED INDEX IX_TitulosBase_IdFact
ON #TitulosBase (IdFactValoresTitulo);

CREATE NONCLUSTERED INDEX IX_TitulosBase_IdJuicio
ON #TitulosBase (IdDimJuicioCoactivo)
WHERE IdDimJuicioCoactivo > 0;

CREATE NONCLUSTERED INDEX IX_TitulosBase_TituloIdentificacion
ON #TitulosBase (AnioTitulo, NumeroTitulo, NumeroCiudadanoKey);


/* ============================================================
   3. COACTIVA DIRECTA VALIDADA
   ============================================================ */

SELECT
    B.IdFactValoresTitulo,

    TipoCruceCoactiva =
        '01_ID_DIRECTO_CONFIRMADO_POR_ANIO_NUMERO' COLLATE Latin1_General_CI_AI,

    PrioridadCruce = 1,

    JC.IdDimJuicioCoactivo AS IdDimJuicioCoactivoCoactiva,
    JC.IdSecuenciaJuicio,
    JC.IdDimTipoDeudaTitulo,

    TDT.TipoDeudaTitulo,
    TDT.TipoDeudaTituloConcepto,

    JC.TipoIngreso,
    JC.TipoSorteo,
    JC.AnioCoactiva,
    JC.NumeroJuicio,
    JC.CodigoJuicio,
    JC.Juzgado,
    JC.Funcionario,
    JC.Estado AS EstadoJuicioCoactiva,
    JC.CoativaObservacion AS ObservacionJuicio,
    JC.ObservacionEliminacion AS ObservacionEliminacionJuicio,

    JC.FechaEstado AS FechaEstadoJuicio,
    JC.FechaIngreso AS FechaIngresoJuicio,
    JC.FechaAsignacion,
    JC.FechaInicioCoactiva,
    JC.FechaAutoPago,
    JC.FechaCitacion,
    JC.FechaUltimoMovimiento,

    JC.TituloCreditoAnio,
    JC.TituloCreditoNumero,
    JC.TituloCreditoFechaExigibilidad,

    JC.IdContribuyente AS IdContribuyenteCoactiva,

    IdentificacionCoactiva =
        NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(30), JC.Identificacion))), '') COLLATE Latin1_General_CI_AI,

    JC.NombreContribuyente AS NombreContribuyenteCoactiva,

    JC.AniosDeuda,
    JC.MontoDeuda,
    JC.MontoPago,
    JC.MontoDeudaCosta,
    JC.MontoPagoCosta,
    JC.CantidadJuicios,

    SaldoCoactivaCabecera =
        ISNULL(JC.MontoDeuda, 0)
      + ISNULL(JC.MontoDeudaCosta, 0)
      - ISNULL(JC.MontoPago, 0)
      - ISNULL(JC.MontoPagoCosta, 0),

    JC.DiasUltimoMovimiento,
    JC.RangoDiasUltimoMovimiento,
    JC.ConceptoDeuda AS ConceptoDeudaCoactiva

INTO #CoactivaDirecta

FROM #TitulosBase AS B

INNER JOIN COACTIVA_DM.JuiciosCoactivos.DimJuicioCoactivo AS JC
    ON JC.IdDimJuicioCoactivo = B.IdDimJuicioCoactivo
   AND B.IdDimJuicioCoactivo > 0
   AND JC.TituloCreditoAnio = B.AnioTitulo
   AND JC.TituloCreditoNumero = B.NumeroTitulo
   AND ISNULL(B.AnioTitulo, 0) > 0
   AND ISNULL(B.NumeroTitulo, 0) > 0

LEFT JOIN COACTIVA_DM.JuiciosCoactivos.DimTipoDeudaTitulo AS TDT
    ON JC.IdDimTipoDeudaTitulo = TDT.IdDimTipoDeudaTitulo;


CREATE CLUSTERED INDEX IX_CoactivaDirecta_IdFact
ON #CoactivaDirecta (IdFactValoresTitulo);


/* ============================================================
   4. COACTIVA POR LLAVE DE NEGOCIO
   Recupera TODOS los juicios asociados por:
   Año título + Número título
   La identificación NO bloquea el cruce.
   ============================================================ */

/* ============================================================
   5. COACTIVA POR AÑO + NÚMERO
   ============================================================ */

SELECT
    B.IdFactValoresTitulo,

    TipoCruceCoactiva =
        '02_ANIO_NUMERO_TITULO' COLLATE Latin1_General_CI_AI,

    PrioridadCruce = 2,

    JC.IdDimJuicioCoactivo AS IdDimJuicioCoactivoCoactiva,
    JC.IdSecuenciaJuicio,
    JC.IdDimTipoDeudaTitulo,

    TDT.TipoDeudaTitulo,
    TDT.TipoDeudaTituloConcepto,

    JC.TipoIngreso,
    JC.TipoSorteo,
    JC.AnioCoactiva,
    JC.NumeroJuicio,
    JC.CodigoJuicio,
    JC.Juzgado,
    JC.Funcionario,
    JC.Estado AS EstadoJuicioCoactiva,
    JC.CoativaObservacion AS ObservacionJuicio,
    JC.ObservacionEliminacion AS ObservacionEliminacionJuicio,

    JC.FechaEstado AS FechaEstadoJuicio,
    JC.FechaIngreso AS FechaIngresoJuicio,
    JC.FechaAsignacion,
    JC.FechaInicioCoactiva,
    JC.FechaAutoPago,
    JC.FechaCitacion,
    JC.FechaUltimoMovimiento,

    JC.TituloCreditoAnio,
    JC.TituloCreditoNumero,
    JC.TituloCreditoFechaExigibilidad,

    JC.IdContribuyente AS IdContribuyenteCoactiva,

    IdentificacionCoactiva =
        NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(30), JC.Identificacion))), '') COLLATE Latin1_General_CI_AI,

    JC.NombreContribuyente AS NombreContribuyenteCoactiva,

    JC.AniosDeuda,
    JC.MontoDeuda,
    JC.MontoPago,
    JC.MontoDeudaCosta,
    JC.MontoPagoCosta,
    JC.CantidadJuicios,

    SaldoCoactivaCabecera =
        ISNULL(JC.MontoDeuda, 0)
      + ISNULL(JC.MontoDeudaCosta, 0)
      - ISNULL(JC.MontoPago, 0)
      - ISNULL(JC.MontoPagoCosta, 0),

    JC.DiasUltimoMovimiento,
    JC.RangoDiasUltimoMovimiento,
    JC.ConceptoDeuda AS ConceptoDeudaCoactiva

INTO #CoactivaAlternativa

FROM #TitulosBase AS B

INNER JOIN COACTIVA_DM.JuiciosCoactivos.DimJuicioCoactivo AS JC
    ON JC.TituloCreditoAnio = B.AnioTitulo
   AND JC.TituloCreditoNumero = B.NumeroTitulo

LEFT JOIN COACTIVA_DM.JuiciosCoactivos.DimTipoDeudaTitulo AS TDT
    ON JC.IdDimTipoDeudaTitulo = TDT.IdDimTipoDeudaTitulo

WHERE
    ISNULL(B.AnioTitulo, 0) > 0
    AND ISNULL(B.NumeroTitulo, 0) > 0;


CREATE CLUSTERED INDEX IX_CoactivaAlternativa_IdFact
ON #CoactivaAlternativa (IdFactValoresTitulo);


/* ============================================================
   6. UNIFICAR, DEDUPLICAR Y CONSERVAR EL ÚLTIMO JUICIO POR TÍTULO

   Reglas:
   1) Se reúnen los cruces válidos.
   2) Se deduplica el mismo IdDimJuicioCoactivo.
   3) Se calcula cuántos juicios distintos tiene el título.
   4) Se conserva únicamente el juicio más reciente.

   Criterio de "último juicio":
      FechaIngresoJuicio DESC
      FechaEstadoJuicio DESC
      AnioCoactiva DESC
      NumeroJuicio DESC
      IdDimJuicioCoactivoCoactiva DESC
   ============================================================ */

SELECT *
INTO #CoactivaCandidata
FROM #CoactivaDirecta

UNION ALL

SELECT *
FROM #CoactivaAlternativa;


CREATE CLUSTERED INDEX IX_CoactivaCandidata_TituloJuicio
ON #CoactivaCandidata
(
    IdFactValoresTitulo,
    IdDimJuicioCoactivoCoactiva,
    PrioridadCruce,
    FechaIngresoJuicio DESC,
    FechaEstadoJuicio DESC
);


;WITH R AS
(
    /* El mismo juicio puede haber sido encontrado por más de una ruta.
       Se conserva una sola versión del juicio. */
    SELECT
        C.*,
        RNJuicio =
            ROW_NUMBER() OVER
            (
                PARTITION BY
                    C.IdFactValoresTitulo,
                    C.IdDimJuicioCoactivoCoactiva
                ORDER BY
                    C.PrioridadCruce ASC,
                    C.FechaIngresoJuicio DESC,
                    C.FechaEstadoJuicio DESC,
                    C.IdSecuenciaJuicio DESC
            )
    FROM #CoactivaCandidata AS C
),
D AS
(
    SELECT *
    FROM R
    WHERE RNJuicio = 1
),
J AS
(
    SELECT
        D.*,

        TotalJuiciosTitulo =
            COUNT_BIG(1) OVER
            (
                PARTITION BY D.IdFactValoresTitulo
            ),

        OrdenUltimoJuicio =
            ROW_NUMBER() OVER
            (
                PARTITION BY D.IdFactValoresTitulo
                ORDER BY
                    CASE WHEN D.FechaIngresoJuicio IS NULL THEN 1 ELSE 0 END ASC,
                    D.FechaIngresoJuicio DESC,
                    CASE WHEN D.FechaEstadoJuicio IS NULL THEN 1 ELSE 0 END ASC,
                    D.FechaEstadoJuicio DESC,
                    ISNULL(D.AnioCoactiva, 0) DESC,
                    ISNULL(D.NumeroJuicio, 0) DESC,
                    D.IdDimJuicioCoactivoCoactiva DESC
            )
    FROM D
)
SELECT
    J.*,
    OrdenJuicioTitulo = CONVERT(BIGINT, 1)
INTO #CoactivaJuicios
FROM J
WHERE J.OrdenUltimoJuicio = 1;


CREATE UNIQUE CLUSTERED INDEX IX_CoactivaJuicios_IdFact
ON #CoactivaJuicios (IdFactValoresTitulo);

CREATE NONCLUSTERED INDEX IX_CoactivaJuicios_IdJuicio
ON #CoactivaJuicios (IdDimJuicioCoactivoCoactiva);


/* ============================================================
   7. DETALLE COACTIVO AGREGADO
   ============================================================ */

SELECT
    CE.IdFactValoresTitulo,

    TotalLineasDetalleCoactiva = COUNT_BIG(1),

    PrimerAnioDeudaDetalle = MIN(D.DetalleJuicio_AnioDeuda),
    UltimoAnioDeudaDetalle = MAX(D.DetalleJuicio_AnioDeuda),

    TotalMontoDeudaDetalle = SUM(ISNULL(D.DetalleJuicio_MontoDeuda, 0)),
    TotalMontoPagoDetalle = SUM(ISNULL(D.DetalleJuicio_MontoPago, 0)),
    TotalMontoPagoDeudaDetalle = SUM(ISNULL(D.DetalleJuicio_MontoPagoDeuda, 0)),
    TotalMontoPagoInteresDetalle = SUM(ISNULL(D.DetalleJuicio_MontoPagoInteres, 0)),
    TotalMontoPagoCoactivaDetalle = SUM(ISNULL(D.DetalleJuicio_MontoPagoCoactiva, 0)),

    FechaPrimerPagoDetalle = MIN(D.DetalleJuicio_FechaPago),
    FechaUltimoPagoDetalle = MAX(D.DetalleJuicio_FechaPago),

    LineasPagadas =
        SUM(
            CASE
                WHEN UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(10), D.DetalleJuicio_Pagado)))) COLLATE Latin1_General_CI_AI IN ('S', 'SI', '1')
                    THEN 1
                ELSE 0
            END
        ),

    LineasNoPagadas =
        SUM(
            CASE
                WHEN UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(10), D.DetalleJuicio_Pagado)))) COLLATE Latin1_General_CI_AI NOT IN ('S', 'SI', '1')
                    THEN 1
                ELSE 0
            END
        ),

    ValorTotalAlCobroDetalle = SUM(ISNULL(D.ValorTotal_AlCobro, 0)),

    TieneConvenioCoactivaDetalle =
        MAX(
            CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(D.Convenio_TieneConvenio, '')))) COLLATE Latin1_General_CI_AI IN ('SI', 'S')
                    THEN 1
                ELSE 0
            END
        ),

    EstadoConvenioCoactiva = MAX(D.EstadoConvenio)

INTO #DetalleCoactivaAgg

FROM #CoactivaJuicios AS CE

INNER JOIN COACTIVA_DM.JuiciosCoactivos.DimDetalleJuicioCoactivo AS D
    ON D.IdDimJuicioCoactivo = CE.IdDimJuicioCoactivoCoactiva

GROUP BY
    CE.IdFactValoresTitulo;


CREATE UNIQUE CLUSTERED INDEX IX_DetalleCoactivaAgg_IdFact
ON #DetalleCoactivaAgg (IdFactValoresTitulo);


/* ============================================================
   8. RESULTADO FINAL PARA POWER BI
   ============================================================ */

SELECT
    /* Corte */
    B.CorteUsado,
    B.FechaCorte,

    /* Llaves */
    B.LlaveTituloCompleta,
    B.IdFactValoresTitulo,
    B.IdDimInfoTitulo,
    B.IdDimContribuyente,
    B.IdDimJuicioCoactivo,

    /* Título */
    B.AnioTitulo,
    B.NumeroTitulo,
    B.IdSolicitud,
    B.ConceptoDeuda,
    B.DireccionTitulo,
    B.FechaEmisionTitulo,
    B.FechaIngresoTitulo,
    B.FechaNotificacionDate,
    B.FechaExigibilidad,
    B.FechaInteresDesde,
    B.FechaCoactivaDesde,

    /* Contribuyente título */
    IdentificacionTitulo = B.NumeroCiudadanoKey,
    NombreContribuyenteTitulo = B.NombreContribuyente,
    B.EstadoRegistroCivil,
    B.EstadoSRI,

    B.FechaFallecimiento,

    /* Estado */
    B.CodEstado,
    B.EstadoTitulo,
    B.EstadoGeneralTitulo,
    B.CondicionJuicioTitulo,
    B.EtapaInicialCiclo,

    /* Tipo de deuda */
    B.IdTipoDeuda,
    B.TipoDeuda,
    B.SubTipoDeuda,
    B.Origen,
    B.Categoria,
    B.TipoDeudaBalance,
    B.SubTipoDeudaBalance,

    /* Convenio */
    B.TieneConvenioTitulo,
    B.AnioConvenioTitulo,
    B.NumeroConvenioTitulo,
    B.FechaSuscripcionConvenioTitulo,
    B.ConvenioAlDiaTitulo,
    B.FechaUltimoPagoConvenioTitulo,
    B.TipoConvenio,

    /* Juicio fecha corte */
    B.TieneJuicioFechaCorte,
    B.JuicioFechaCorte,
    B.EstadoJuicioFechaCorte,
    B.JuzgadoFechaCorte,

    /* Valores */
    B.CantidadTitulos,
    B.ValorTitulo,
    B.ValorDeuda,
    B.ValorTasa,
    B.ValorInteres,
    B.ValorMulta,
    B.ValorCoactiva,
    B.ValorDescuento,
    B.ValorConvenio,
    B.ValorTotal,

    B.ValorDeuda_AlCobro,
    B.ValorDescuento_AlCobro,
    B.ValorInteres_AlCobro,
    B.ValorMulta_AlCobro,
    B.ValorTasa_AlCobro,
    B.ValorRecargo_AlCobro,
    B.ValorCoactiva_AlCobro,
    B.ValorPagoConvenio_AlCobro,
    B.ValorTotal_AlCobro,

    DiferenciaValorTituloVsAlCobro =
        ISNULL(B.ValorTitulo, 0) - ISNULL(B.ValorTotal_AlCobro, 0),

    /* ========================================================
       CONTROL DE GRANULARIDAD POWER BI
       Esta versión ya devuelve UNA FILA POR TÍTULO.
       Las columnas *_Unico se conservan por compatibilidad
       y son iguales al valor original del título.
       ======================================================== */
    EsPrimeraFilaTitulo = 1,

    ValorTitulo_Unico = B.ValorTitulo,
    ValorDeuda_AlCobro_Unico = B.ValorDeuda_AlCobro,
    ValorTotal_AlCobro_Unico = B.ValorTotal_AlCobro,

    /* Cruce coactiva */
    TieneCruceCoactiva =
        CASE WHEN CE.IdFactValoresTitulo IS NOT NULL THEN 1 ELSE 0 END,

    CE.TipoCruceCoactiva,
    IdDimJuicioCoactivoUltimo = CE.IdDimJuicioCoactivoCoactiva,
    CE.TotalJuiciosTitulo,
    EsUltimoJuicioTitulo = CASE WHEN CE.IdFactValoresTitulo IS NOT NULL THEN 1 ELSE 0 END,
    CE.OrdenJuicioTitulo,
    CE.IdSecuenciaJuicio,
    CE.IdDimTipoDeudaTitulo,
    CE.TipoDeudaTitulo,
    CE.TipoDeudaTituloConcepto,

    /* Cabecera juicio */
    CE.TipoIngreso,
    CE.TipoSorteo,
    CE.AnioCoactiva,
    CE.NumeroJuicio,
    CE.CodigoJuicio,
    CE.Juzgado,
    CE.Funcionario,
    CE.EstadoJuicioCoactiva,
    CE.ObservacionJuicio,
    ObservacionEliminacion = CE.ObservacionEliminacionJuicio,

    CE.FechaEstadoJuicio,
    CE.FechaIngresoJuicio,
    CE.FechaAsignacion,
    CE.FechaInicioCoactiva,
    CE.FechaAutoPago,
    CE.FechaCitacion,
    CE.FechaUltimoMovimiento,

    IdentificacionCoactiva = CE.IdentificacionCoactiva,
    NombreContribuyenteCoactiva = CE.NombreContribuyenteCoactiva,

    CoincideIdentificacionTituloCoactiva =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
                THEN NULL

            WHEN B.NumeroCiudadanoKey IS NULL
              OR REPLACE(B.NumeroCiudadanoKey, '0', '') = ''
                THEN NULL

            WHEN CE.IdentificacionCoactiva IS NULL
              OR REPLACE(CE.IdentificacionCoactiva, '0', '') = ''
                THEN NULL

            WHEN B.NumeroCiudadanoKey COLLATE Latin1_General_CI_AI
                 =
                 CE.IdentificacionCoactiva COLLATE Latin1_General_CI_AI
                THEN 1

            ELSE 0
        END,

    AlertaCruceContribuyente =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
                THEN 'SIN CRUCE COACTIVA'

            WHEN B.NumeroCiudadanoKey IS NULL
              OR REPLACE(B.NumeroCiudadanoKey, '0', '') = ''
                THEN 'IDENTIFICACION DEL TITULO NO UTILIZABLE PARA CONTRASTE'

            WHEN CE.IdentificacionCoactiva IS NULL
              OR REPLACE(CE.IdentificacionCoactiva, '0', '') = ''
                THEN 'IDENTIFICACION DE COACTIVA NO UTILIZABLE PARA CONTRASTE'

            WHEN B.NumeroCiudadanoKey COLLATE Latin1_General_CI_AI
                 =
                 CE.IdentificacionCoactiva COLLATE Latin1_General_CI_AI
                THEN 'CONTRIBUYENTE COINCIDE POR IDENTIFICACION'

            ELSE 'ALERTA: IDENTIFICACION TITULO DIFIERE DE COACTIVA'
        END,

    CalidadCruceCoactiva =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
                THEN 'SIN CRUCE POR ANIO + NUMERO'

            WHEN CE.PrioridadCruce = 1
                THEN 'ALTA - ID DIRECTO CONFIRMADO POR ANIO + NUMERO'

            WHEN CE.PrioridadCruce = 2
             AND B.NumeroCiudadanoKey IS NOT NULL
             AND REPLACE(B.NumeroCiudadanoKey, '0', '') <> ''
             AND CE.IdentificacionCoactiva IS NOT NULL
             AND REPLACE(CE.IdentificacionCoactiva, '0', '') <> ''
             AND B.NumeroCiudadanoKey COLLATE Latin1_General_CI_AI
                 = CE.IdentificacionCoactiva COLLATE Latin1_General_CI_AI
                THEN 'ALTA - ANIO + NUMERO + IDENTIFICACION COINCIDENTE'

            WHEN CE.PrioridadCruce = 2
                THEN 'ALTA - ANIO + NUMERO; IDENTIFICACION SOLO CONTROL'

            ELSE 'REVISAR'
        END,

    EsIdJuicioOriginalIgualUltimo =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL THEN NULL
            WHEN B.IdDimJuicioCoactivo = CE.IdDimJuicioCoactivoCoactiva THEN 1
            ELSE 0
        END,

    /* Auditoría del IdDimJuicioCoactivo informado en títulos */
    IdJuicioInformadoTitulo = B.IdDimJuicioCoactivo,
    CodigoJuicioIdInformado = JCID.CodigoJuicio,
    AnioTituloIdInformado = JCID.TituloCreditoAnio,
    NumeroTituloIdInformado = JCID.TituloCreditoNumero,
    IdentificacionIdInformado = JCID.Identificacion,

    ValidacionIdJuicioInformado =
        CASE
            WHEN ISNULL(B.IdDimJuicioCoactivo, 0) = 0
                THEN 'SIN ID INFORMADO EN TITULOS'

            WHEN JCID.IdDimJuicioCoactivo IS NULL
                THEN 'ID INFORMADO NO EXISTE EN DIMJUICIOCOACTIVO'

            WHEN JCID.TituloCreditoAnio = B.AnioTitulo
             AND JCID.TituloCreditoNumero = B.NumeroTitulo
                THEN 'ID CONSISTENTE CON ANIO + NUMERO DEL TITULO'

            WHEN ISNULL(JCID.TituloCreditoAnio, 0) = 0
             AND ISNULL(JCID.TituloCreditoNumero, 0) = 0
                THEN 'ID EXISTE PERO COACTIVA NO TIENE CLAVE DE TITULO - NO USAR COMO VINCULO'

            ELSE 'ALERTA: ID EXISTE PERO APUNTA A OTRO ANIO/NUMERO DE TITULO'
        END,

    CE.AniosDeuda,
    CE.MontoDeuda AS MontoDeudaCoactivaCabecera,
    CE.MontoPago AS MontoPagoCoactivaCabecera,
    CE.MontoDeudaCosta,
    CE.MontoPagoCosta,
    CE.SaldoCoactivaCabecera,
    CE.CantidadJuicios,
    CE.DiasUltimoMovimiento,
    CE.RangoDiasUltimoMovimiento,

    /* Detalle agregado */
    DCA.TotalLineasDetalleCoactiva,
    DCA.PrimerAnioDeudaDetalle,
    DCA.UltimoAnioDeudaDetalle,
    DCA.TotalMontoDeudaDetalle,
    DCA.TotalMontoPagoDetalle,
    DCA.TotalMontoPagoDeudaDetalle,
    DCA.TotalMontoPagoInteresDetalle,
    DCA.TotalMontoPagoCoactivaDetalle,
    DCA.FechaPrimerPagoDetalle,
    DCA.FechaUltimoPagoDetalle,
    DCA.LineasPagadas,
    DCA.LineasNoPagadas,
    DCA.ValorTotalAlCobroDetalle,
    DCA.TieneConvenioCoactivaDetalle,
    DCA.EstadoConvenioCoactiva,

    /* Indicadores calculados */

    /* Clasificación final */
    EstadoFinalCiclo =
        CASE
            WHEN B.FechaBaja IS NOT NULL
                THEN 'CICLO CERRADO: TITULO DADO DE BAJA'

            WHEN B.FechaFallecimiento IS NOT NULL
                THEN 'REVISAR: CONTRIBUYENTE FALLECIDO'

            WHEN CE.IdFactValoresTitulo IS NULL
                 AND B.CondicionJuicioTitulo = 'EN COACTIVA CON ID JUICIO EN TITULOS'
                THEN 'BRECHA: ID JUICIO EN TITULOS NO VALIDADO CONTRA COACTIVA'

            WHEN CE.IdFactValoresTitulo IS NULL
                 AND B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
                 AND ISNULL(B.IdDimJuicioCoactivoFechaCorte, 0) = 0
                 AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NULL'
                THEN 'ENVIADO A COACTIVA SIN FORMALIZACION DE JUICIO'

            WHEN CE.IdFactValoresTitulo IS NULL
                 AND B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
                 AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NO'
                THEN 'EN COACTIVA SIN JUICIO ACTIVO EN FECHA CORTE'

            WHEN CE.IdFactValoresTitulo IS NULL
                 AND UPPER(LTRIM(RTRIM(B.EstadoGeneralTitulo))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
                THEN 'EN GESTION DE TITULO: AUN NO ENLAZADO A COACTIVA'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND ISNULL(CE.SaldoCoactivaCabecera, 0) <= 0
                THEN 'CICLO CERRADO: COACTIVA PAGADA / SIN SALDO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND ISNULL(DCA.TotalMontoDeudaDetalle, 0) - ISNULL(DCA.TotalMontoPagoDeudaDetalle, 0) <= 0
                 AND DCA.TotalLineasDetalleCoactiva IS NOT NULL
                THEN 'CICLO CERRADO: DETALLE COACTIVO PAGADO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND ISNULL(DCA.TieneConvenioCoactivaDetalle, 0) = 1
                THEN 'EN COACTIVA CON CONVENIO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND CE.FechaCitacion IS NOT NULL
                THEN 'EN COACTIVA: CITADO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND CE.FechaAutoPago IS NOT NULL
                THEN 'EN COACTIVA: AUTO DE PAGO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                 AND CE.FechaInicioCoactiva IS NOT NULL
                THEN 'EN COACTIVA: INICIADO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                THEN 'EN COACTIVA: REGISTRADO'

            ELSE 'NO CLASIFICADO'
        END,

    SubEstadoTrazabilidad =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
             AND B.CondicionJuicioTitulo = 'EN COACTIVA CON ID JUICIO EN TITULOS'
                THEN 'ID JUICIO EN TITULOS NO VALIDADO CONTRA COACTIVA'

            WHEN B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
             AND CE.IdFactValoresTitulo IS NULL
             AND ISNULL(B.IdDimJuicioCoactivoFechaCorte, 0) = 0
             AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NULL'
                THEN 'ENVIADO A COACTIVA SIN FORMALIZACION DE JUICIO'

            WHEN B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
             AND CE.IdFactValoresTitulo IS NULL
             AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NO'
                THEN 'EN COACTIVA SIN JUICIO ACTIVO EN FECHA CORTE'

            WHEN UPPER(LTRIM(RTRIM(B.EstadoGeneralTitulo))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
             AND CE.IdFactValoresTitulo IS NULL
                THEN 'EN PROCESO DE TITULO SIN ENVIO FORMAL A COACTIVA'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                THEN 'TRAZABILIDAD COACTIVA ENCONTRADA'

            ELSE 'REVISAR'
        END,

    AlertaAuditoria =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
             AND B.CondicionJuicioTitulo = 'EN COACTIVA CON ID JUICIO EN TITULOS'
                THEN 'ALTA: NO SE ENCONTRO JUICIO POR ANIO + NUMERO DEL TITULO'

            WHEN B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
             AND CE.IdFactValoresTitulo IS NULL
             AND ISNULL(B.IdDimJuicioCoactivoFechaCorte, 0) = 0
             AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NULL'
                THEN 'ALTA: TITULO ENVIADO A COACTIVA SIN FORMALIZACION DE JUICIO'

            WHEN B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
             AND CE.IdFactValoresTitulo IS NULL
             AND COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(20), B.TieneJuicioFechaCorte))), ''), 'NULL') = 'NO'
                THEN 'MEDIA: TITULO EN COACTIVA SIN JUICIO ACTIVO EN FECHA CORTE'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
             AND DCA.TotalLineasDetalleCoactiva IS NULL
                THEN 'MEDIA: EXISTE CABECERA COACTIVA SIN DETALLE'

            ELSE 'OK / SIN ALERTA CRITICA'
        END,

    AccionRecomendadaAuditoria =
        CASE
            WHEN CE.IdFactValoresTitulo IS NULL
             AND B.CondicionJuicioTitulo = 'EN COACTIVA CON ID JUICIO EN TITULOS'
                THEN 'REVISAR ANIO Y NUMERO DEL TITULO CONTRA DIMJUICIOCOACTIVO'

            WHEN B.CondicionJuicioTitulo = 'EN COACTIVA SIN ID JUICIO EN TITULOS'
             AND CE.IdFactValoresTitulo IS NULL
             AND ISNULL(B.IdDimJuicioCoactivoFechaCorte, 0) = 0
                THEN 'VALIDAR SI EL ENVIO A COACTIVA GENERO CABECERA DE JUICIO; REVISAR PROCESO ETL O REGISTRO OPERATIVO'

            WHEN UPPER(LTRIM(RTRIM(B.EstadoGeneralTitulo))) COLLATE Latin1_General_CI_AI LIKE '%PROCESO%TITULO%'
             AND CE.IdFactValoresTitulo IS NULL
                THEN 'NO ES BRECHA CRITICA; TITULO AUN NO TIENE JUICIO COACTIVO'

            WHEN CE.IdFactValoresTitulo IS NOT NULL
                THEN 'SIN ACCION; CRUCE COACTIVO OK'

            ELSE 'REVISAR CASO'
        END

FROM #TitulosBase AS B

LEFT JOIN #CoactivaJuicios AS CE
    ON B.IdFactValoresTitulo = CE.IdFactValoresTitulo

LEFT JOIN #DetalleCoactivaAgg AS DCA
    ON B.IdFactValoresTitulo = DCA.IdFactValoresTitulo

LEFT JOIN COACTIVA_DM.JuiciosCoactivos.DimJuicioCoactivo AS JCID
    ON JCID.IdDimJuicioCoactivo = B.IdDimJuicioCoactivo


ORDER BY
    B.AnioTitulo,
    B.NumeroTitulo,
    B.NumeroCiudadanoKey

OPTION (RECOMPILE);
