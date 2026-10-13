/*
 * ============================================================================
 * CONSULTA: cartera consolidada
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : CARTERA (base de la página GEORREFERENCIACIÓN de SICOGE)
 * Qué responde        : Cartera consolidada: coactiva en deuda más títulos en deuda sin contraparte coactiva. Segmenta por Pareto (A a E), califica la calidad de la ubicación y trae parroquia y sector.
 * Bases de origen     : CONTRIBUYENTE_DM.dbo.Deuda, TITULOS_CREDITO_DM, COACTIVA_DM
 * Granularidad        : Una fila por obligación
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/* ============================================================
   POWER BI - CARTERA CONSOLIDADA
   Base principal: CONTRIBUYENTE_DM.dbo.Deuda

   VALORES:
   - ValorDeuda / ValorTotal:
       PRINCIPALES desde dbo.Deuda
   - ValorDeudaTmp / ValorTotalTmp:
       corte temporal desde TmpDeudasCoactiva / TmpDeudasTituloCredito
   - ValorDeudaReferencial / ValorTotalReferencial:
       referencia oficial desde COACTIVA_DM / TITULOS_CREDITO_DM

   DEFINICIÓN:
   COACTIVA EN DEUDA
   +
   TÍTULOS EN DEUDA SIN CONTRAPARTE COACTIVA

   RESULTADO ESPERADO:
   Obligaciones     : <total>
   Contribuyentes   : <total>
   ValorTotal       : <total>
   ============================================================ */

;WITH UltimoCorteTitulo AS
(
    SELECT TOP (1)
        FC.IdDimFechaCorte,
        FC.FechaCorte
    FROM [TITULOS_CREDITO_DM].[dbo].[DimFechaCorte] FC
    ORDER BY
        FC.FechaCorte DESC,
        FC.IdDimFechaCorte DESC
),

/* ============================================================
   CORTE OFICIAL COACTIVA
   Nota: en COACTIVA_DM el IdDimFechaCorte no está relacionado
   directamente con DimJuicioCoactivo, por lo que se incorpora
   como metadato del corte y NO como filtro de los juicios.
   ============================================================ */
UltimoCorteCoactiva AS
(
    SELECT TOP (1)
        FC.IdDimFechaCorte,
        FC.FechaCorte,
        FC.FechaCorteLetras
    FROM [COACTIVA_DM].[JuiciosCoactivos].[DimFechaCorte] FC
    ORDER BY
        FC.FechaCorte DESC,
        FC.IdDimFechaCorte DESC
),

/* ============================================================
   CONTROL DE SINCRONIZACIÓN ENTRE FUENTES
   FechaCorte se informa únicamente cuando Títulos y Coactiva
   corresponden al mismo día calendario.
   ============================================================ */
CortesFuentes AS
(
    SELECT
        CASE
            WHEN CAST(UT.FechaCorte AS date) = CAST(UC.FechaCorte AS date)
                THEN CAST(UT.FechaCorte AS date)
            ELSE NULL
        END AS FechaCorte
    FROM UltimoCorteTitulo UT
    CROSS JOIN UltimoCorteCoactiva UC
),

TituloFuenteBase AS
(
    SELECT
        I.IdSolicitud,
        I.AnioTitulo,
        I.NumeroTitulo,
        I.ConceptoDeuda AS ConceptoDeudaTituloReferencial,

        F.ValorTotal AS ValorDeudaReferencialTitulo,
        F.ValorTotal_AlCobro AS ValorTotalReferencialTitulo,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                I.AnioTitulo,
                I.NumeroTitulo,
                I.IdSolicitud
            ORDER BY
                F.IdFactValoresTitulo DESC,
                I.IdDimInfoTitulo DESC
        ) AS RN

    FROM UltimoCorteTitulo UC

    INNER JOIN [TITULOS_CREDITO_DM].[dbo].[FactValoresTitulo] F
        ON F.IdDimFechaCorte = UC.IdDimFechaCorte

    INNER JOIN [TITULOS_CREDITO_DM].[dbo].[DimInfoTitulo] I
        ON I.IdDimInfoTitulo = F.IdDimInfoTitulo
),

TituloActual AS
(
    SELECT
        IdSolicitud,
        AnioTitulo,
        NumeroTitulo,
        ConceptoDeudaTituloReferencial,
        ValorDeudaReferencialTitulo,
        ValorTotalReferencialTitulo
    FROM TituloFuenteBase
    WHERE RN = 1
),

JuicioFuenteBase AS
(
    SELECT
        J.IdSecuenciaJuicio,
        J.AnioCoactiva AS AnioJuicio,
        J.CodigoJuicio AS NumeroJuicio,
        J.ConceptoDeuda AS ConceptoDeudaCoactivaReferencial,
        J.MontoDeuda,
        J.MontoPago,

        ROW_NUMBER() OVER
        (
            PARTITION BY J.IdSecuenciaJuicio
            ORDER BY J.IdDimJuicioCoactivo DESC
        ) AS RN

    FROM [COACTIVA_DM].[JuiciosCoactivos].[DimJuicioCoactivo] J
    WHERE J.IdSecuenciaJuicio IS NOT NULL
),

JuicioActual AS
(
    SELECT
        IdSecuenciaJuicio,
        AnioJuicio,
        NumeroJuicio,
        ConceptoDeudaCoactivaReferencial,
        MontoDeuda,
        MontoPago
    FROM JuicioFuenteBase
    WHERE RN = 1
),

TmpCoactiva AS
(
    SELECT
        AnioIdDeuda,
        NumeroIdDeuda,
        ISNULL(NumeroIdAuxDeuda,0) AS NumeroIdAuxDeuda,
        SUM(CAST(ValorDeuda AS decimal(18,2))) AS ValorDeudaTmp,
        SUM(CAST(ValorTotal AS decimal(18,2))) AS ValorTotalTmp
    FROM dbo.TmpDeudasCoactiva
    WHERE CodFaseDeuda = 'COA'
    GROUP BY
        AnioIdDeuda,
        NumeroIdDeuda,
        ISNULL(NumeroIdAuxDeuda,0)
),

TmpTitulos AS
(
    SELECT
        AnioIdDeuda,
        NumeroIdDeuda,
        ISNULL(NumeroIdAuxDeuda,0) AS NumeroIdAuxDeuda,
        SUM(CAST(ValorDeuda AS decimal(18,2))) AS ValorDeudaTmp,
        SUM(CAST(ValorTotal AS decimal(18,2))) AS ValorTotalTmp
    FROM dbo.TmpDeudasTituloCredito
    WHERE CodFaseDeuda = 'TIT'
    GROUP BY
        AnioIdDeuda,
        NumeroIdDeuda,
        ISNULL(NumeroIdAuxDeuda,0)
),

CoactivaReferencia AS
(
    /* --------------------------------------------------------
       Referencias válidas existentes en COACTIVA
       Se excluyen referencias 0 / 0
       -------------------------------------------------------- */
    SELECT DISTINCT
        D.IdContribuyente,
        D.AnioTitulo,
        D.NumeroTitulo
    FROM dbo.Deuda D
    WHERE
        D.CodFaseDeuda = 'COA'
        AND ISNULL(D.AnioTitulo, 0) > 0
        AND ISNULL(D.NumeroTitulo, 0) > 0
),

CarteraBase AS
(
    /* --------------------------------------------------------
       Construcción de cartera sin doble contabilización
       -------------------------------------------------------- */
    SELECT
        D.IdDeuda,
        D.IdContribuyente,
        D.IdUbicacion,

        /* CONTRIBUYENTE */
        C.Identificacion,
        C.Cedula,
        C.Ruc,
        C.NombreContribuyente,

        /* FASE */
        D.CodFaseDeuda,
        D.FaseDeuda,

        /* DEUDA / RUBRO */
        D.TipoDeuda,

        /* IDENTIFICACIÓN DE LA DEUDA */
        D.AnioIdDeuda,
        D.NumeroIdDeuda,
        D.NumeroIdAuxDeuda,

        /* REFERENCIA AL TÍTULO */
        D.AnioTitulo,
        D.NumeroTitulo,

        /* ESTADO */
        D.EstadoGeneral,
        D.EstadoEspecifico,

        /* FECHAS */
        D.FechaVigenciaDesde,
        D.FechaVigenciaHasta,
        D.FechaPago,

        /* =====================================================
           VALORES PRINCIPALES
           Fuente: CONTRIBUYENTE_DM.dbo.Deuda
           ===================================================== */
        D.ValorDeuda,
        D.ValorTotal,

        /* =====================================================
           VALORES DEL CORTE TEMPORAL
           Fuente: TmpDeudasCoactiva / TmpDeudasTituloCredito
           ===================================================== */
        CASE
            WHEN D.CodFaseDeuda = 'COA' THEN TC.ValorDeudaTmp
            WHEN D.CodFaseDeuda = 'TIT' THEN TT.ValorDeudaTmp
        END AS ValorDeudaTmp,

        CASE
            WHEN D.CodFaseDeuda = 'COA' THEN TC.ValorTotalTmp
            WHEN D.CodFaseDeuda = 'TIT' THEN TT.ValorTotalTmp
        END AS ValorTotalTmp,

        /* =====================================================
           VALORES REFERENCIALES
           Fuente: COACTIVA_DM / TITULOS_CREDITO_DM
           ===================================================== */
        CASE
            WHEN D.CodFaseDeuda = 'COA'
                THEN CAST(JA.MontoDeuda AS decimal(18,2))
            WHEN D.CodFaseDeuda = 'TIT'
                THEN CAST(TA.ValorDeudaReferencialTitulo AS decimal(18,2))
        END AS ValorDeudaReferencial,

        CASE
            WHEN D.CodFaseDeuda = 'COA'
                THEN CAST(
                    JA.MontoDeuda - ISNULL(JA.MontoPago,0)
                    AS decimal(18,2)
                )
            WHEN D.CodFaseDeuda = 'TIT'
                THEN CAST(TA.ValorTotalReferencialTitulo AS decimal(18,2))
        END AS ValorTotalReferencial,

        /* JUICIO Y CONCEPTOS DE LA FUENTE OFICIAL */
        CASE
            WHEN D.CodFaseDeuda = 'COA' THEN JA.AnioJuicio
        END AS AnioJuicio,

        CASE
            WHEN D.CodFaseDeuda = 'COA' THEN JA.NumeroJuicio
        END AS NumeroJuicio,

        CASE
            WHEN D.CodFaseDeuda = 'TIT'
                THEN TA.ConceptoDeudaTituloReferencial
        END AS ConceptoDeudaTituloReferencial,

        CASE
            WHEN D.CodFaseDeuda = 'COA'
                THEN JA.ConceptoDeudaCoactivaReferencial
        END AS ConceptoDeudaCoactivaReferencial,

        D.ValorTotal - D.ValorDeuda
            AS DiferenciaValor,

        /* DATOS PREDIALES / CATASTRALES */
        D.Sector,
        D.Manzana,
        D.Lote,
        D.Division,
        D.Phv,
        D.Phh,
        D.Numero,
        D.NumeroEstablecimientoSri,

        /* UBICACIÓN */
        D.TieneUbicacionSN,
        D.UbicacionAsociadaDeudaSN,
        D.OrigenUbicacion,
        D.NivelConfianzaUbicacion,

        D.DireccionUbicacion,
        D.LatitudUbicacion,
        D.LongitudUbicacion,

        /* GEOGRAFÍA NORMALIZADA */
        NULLIF(
            LTRIM(RTRIM(D.AGA)),
            ''
        ) AS AGA,

        NULLIF(
            LTRIM(RTRIM(D.PARROQUIA)),
            ''
        ) AS Parroquia,

        NULLIF(
            LTRIM(RTRIM(D.SECT_NOMEN)),
            ''
        ) AS SectorNomenclatura,

        /* ----------------------------------------------
           CLAVE DE REFERENCIA ANALÍTICA
           ---------------------------------------------- */
        CASE
            WHEN D.CodFaseDeuda = 'COA'
             AND ISNULL(D.AnioTitulo,0) > 0
             AND ISNULL(D.NumeroTitulo,0) > 0
            THEN CONCAT(
                    D.IdContribuyente, '|',
                    D.AnioTitulo, '|',
                    D.NumeroTitulo
                 )

            WHEN D.CodFaseDeuda = 'TIT'
            THEN CONCAT(
                    D.IdContribuyente, '|',
                    D.AnioIdDeuda, '|',
                    D.NumeroIdDeuda
                 )

            ELSE CONCAT(
                    'COA-SIN-REF|',
                    D.IdDeuda
                 )
        END AS ClaveReferenciaTitulo,

        /* ----------------------------------------------
           ORIGEN DE CARTERA
           ---------------------------------------------- */
        CASE
            WHEN D.CodFaseDeuda = 'COA'
                THEN 'COACTIVA'

            WHEN D.CodFaseDeuda = 'TIT'
                THEN 'TITULO'

            ELSE 'OTRO'
        END AS OrigenCartera,

        /* ----------------------------------------------
           TRAZABILIDAD
           ---------------------------------------------- */
        CASE
            WHEN D.CodFaseDeuda = 'COA'
             AND ISNULL(D.AnioTitulo,0) > 0
             AND ISNULL(D.NumeroTitulo,0) > 0
                THEN 'COACTIVA CON REFERENCIA'

            WHEN D.CodFaseDeuda = 'COA'
                THEN 'COACTIVA SIN REFERENCIA'

            WHEN D.CodFaseDeuda = 'TIT'
             AND CR.IdContribuyente IS NULL
                THEN 'TITULO SIN CONTRAPARTE COACTIVA'

            ELSE 'REVISAR'
        END AS EstadoTrazabilidad,

        /* ----------------------------------------------
           ANTIGÜEDAD
           Año de corte: 2026
           ---------------------------------------------- */
        2026 - D.AnioIdDeuda
            AS AntiguedadAnios,

        CASE
            WHEN D.AnioIdDeuda = 2026
                THEN '00. AÑO ACTUAL'

            WHEN 2026 - D.AnioIdDeuda = 1
                THEN '01. 1 AÑO'

            WHEN 2026 - D.AnioIdDeuda BETWEEN 2 AND 3
                THEN '02. 2-3 AÑOS'

            WHEN 2026 - D.AnioIdDeuda BETWEEN 4 AND 5
                THEN '03. 4-5 AÑOS'

            WHEN 2026 - D.AnioIdDeuda BETWEEN 6 AND 10
                THEN '04. 6-10 AÑOS'

            WHEN 2026 - D.AnioIdDeuda > 10
                THEN '05. MÁS DE 10 AÑOS'

            ELSE '99. REVISAR'
        END AS RangoAntiguedad,

        /* ----------------------------------------------
           CALIDAD DE GEOREFERENCIACIÓN
           ---------------------------------------------- */
        CASE
            WHEN D.IdUbicacion IS NULL
                THEN '01. SIN UBICACION'

            WHEN D.LatitudUbicacion IS NULL
              OR D.LongitudUbicacion IS NULL
                THEN '02. SIN COORDENADAS'

            WHEN NULLIF(
                    LTRIM(RTRIM(D.PARROQUIA)),
                    ''
                 ) IS NULL
                THEN '03. SIN PARROQUIA'

            WHEN NULLIF(
                    LTRIM(RTRIM(D.SECT_NOMEN)),
                    ''
                 ) IS NULL
                THEN '04. SIN SECTOR'

            ELSE '05. UBICACION COMPLETA'
        END AS CalidadUbicacion

    FROM dbo.Deuda D

    INNER JOIN dbo.Contribuyente C
        ON D.IdContribuyente = C.IdContribuyente

    /* FUENTE OFICIAL: solo aporta referencias/validación */
    LEFT JOIN JuicioActual JA
        ON D.CodFaseDeuda = 'COA'
       AND JA.IdSecuenciaJuicio = D.NumeroIdDeuda

    LEFT JOIN TituloActual TA
        ON D.CodFaseDeuda = 'TIT'
       AND TA.AnioTitulo = D.AnioIdDeuda
       AND TA.NumeroTitulo = D.NumeroIdDeuda
       AND TA.IdSolicitud = D.NumeroIdAuxDeuda

    /* TABLAS TEMPORALES: solo aportan valores del corte */
    LEFT JOIN TmpCoactiva TC
        ON D.CodFaseDeuda = 'COA'
       AND TC.AnioIdDeuda = D.AnioIdDeuda
       AND TC.NumeroIdDeuda = D.NumeroIdDeuda
       AND TC.NumeroIdAuxDeuda = ISNULL(D.NumeroIdAuxDeuda,0)

    LEFT JOIN TmpTitulos TT
        ON D.CodFaseDeuda = 'TIT'
       AND TT.AnioIdDeuda = D.AnioIdDeuda
       AND TT.NumeroIdDeuda = D.NumeroIdDeuda
       AND TT.NumeroIdAuxDeuda = ISNULL(D.NumeroIdAuxDeuda,0)

    LEFT JOIN CoactivaReferencia CR
        ON D.CodFaseDeuda = 'TIT'
       AND D.IdContribuyente = CR.IdContribuyente
       AND D.AnioIdDeuda = CR.AnioTitulo
       AND D.NumeroIdDeuda = CR.NumeroTitulo

    WHERE
        D.EstadoGeneral = 'EN DEUDA'

        AND
        (
            /* Todas las COACTIVAS activas */
            D.CodFaseDeuda = 'COA'

            OR

            /* TÍTULOS activos solamente si no tienen COA */
            (
                D.CodFaseDeuda = 'TIT'
                AND CR.IdContribuyente IS NULL
            )
        )
),

Deudores AS
(
    /* --------------------------------------------------------
       Consolidación por contribuyente
       -------------------------------------------------------- */
    SELECT
        IdContribuyente,

        COUNT_BIG(*) AS ObligacionesContribuyente,

        SUM(ValorTotal)
            AS DeudaTotalContribuyente,

        SUM(
            CASE
                WHEN CodFaseDeuda = 'COA'
                THEN ValorTotal
                ELSE 0
            END
        ) AS DeudaCoactivaContribuyente,

        SUM(
            CASE
                WHEN CodFaseDeuda = 'TIT'
                THEN ValorTotal
                ELSE 0
            END
        ) AS DeudaTituloContribuyente,

        MIN(AnioIdDeuda)
            AS AnioDeudaMasAntigua,

        MAX(AnioIdDeuda)
            AS AnioDeudaMasReciente

    FROM CarteraBase

    GROUP BY
        IdContribuyente
),

RankingBase AS
(
    SELECT
        D.*,

        ROW_NUMBER() OVER
        (
            ORDER BY
                D.DeudaTotalContribuyente DESC,
                D.IdContribuyente
        ) AS RankingDeudor,

        SUM(D.DeudaTotalContribuyente) OVER
        (
            ORDER BY
                D.DeudaTotalContribuyente DESC,
                D.IdContribuyente

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW
        ) AS DeudaAcumulada,

        SUM(D.DeudaTotalContribuyente) OVER ()
            AS CarteraTotal

    FROM Deudores D
),

Ranking AS
(
    SELECT
        R.*,

        CAST(
            100.0
            * R.DeudaTotalContribuyente
            / NULLIF(R.CarteraTotal,0)

            AS decimal(12,6)
        ) AS ParticipacionIndividualPct,

        CAST(
            100.0
            * R.DeudaAcumulada
            / NULLIF(R.CarteraTotal,0)

            AS decimal(12,6)
        ) AS ParticipacionAcumuladaPct,

        CAST(
            100.0
            * (
                R.DeudaAcumulada
                - R.DeudaTotalContribuyente
              )
            / NULLIF(R.CarteraTotal,0)

            AS decimal(12,6)
        ) AS ParticipacionAnteriorPct

    FROM RankingBase R
),

Segmentacion AS
(
    SELECT
        R.*,

        /* ----------------------------------------------------
           Segmentación estratégica Pareto

           Se utiliza el acumulado ANTERIOR para que
           el contribuyente que completa el 80 %, 90 %, etc.
           permanezca en el segmento correspondiente.
           ---------------------------------------------------- */
        CASE
            WHEN R.ParticipacionAnteriorPct < 80
                THEN 'A - ESTRATEGICO 0-80%'

            WHEN R.ParticipacionAnteriorPct < 90
                THEN 'B - ALTO VALOR 80-90%'

            WHEN R.ParticipacionAnteriorPct < 95
                THEN 'C - MEDIO 90-95%'

            WHEN R.ParticipacionAnteriorPct < 99
                THEN 'D - MASIVO 95-99%'

            ELSE
                'E - MICRO CARTERA 99-100%'
        END AS SegmentoGestion

    FROM Ranking R
)

SELECT
    /* ========================================================
       RESULTADO FINAL PARA POWER BI
       1 fila = 1 obligación de cartera consolidada
       ======================================================== */

    CB.IdDeuda,
    CB.IdContribuyente,
    CB.IdUbicacion,

    /* CONTRIBUYENTE */
    CB.Identificacion,
    CB.Cedula,
    CB.Ruc,
    CB.NombreContribuyente,

    /* DEUDA */
    CB.CodFaseDeuda,
    CB.FaseDeuda,
    CB.OrigenCartera,

    CB.TipoDeuda,

    CB.AnioIdDeuda,
    CB.NumeroIdDeuda,
    CB.NumeroIdAuxDeuda,

    CB.AnioTitulo,
    CB.NumeroTitulo,

    CB.ClaveReferenciaTitulo,

    /* ESTADO */
    CB.EstadoGeneral,
    CB.EstadoEspecifico,
    CB.EstadoTrazabilidad,

    /* FECHA DE CORTE MAESTRA */
    CF.FechaCorte,

    /* FECHAS DE LA OBLIGACIÓN */
    CB.FechaVigenciaDesde,
    CB.FechaVigenciaHasta,
    CB.FechaPago,

    /* VALORES PRINCIPALES - dbo.Deuda */
    CB.ValorDeuda,
    CB.ValorTotal,

    /* VALORES DEL CORTE TEMPORAL */
    CB.ValorDeudaTmp,
    CB.ValorTotalTmp,

    /* VALORES REFERENCIALES - FUENTES OFICIALES */
    CB.ValorDeudaReferencial,
    CB.ValorTotalReferencial,

    /* JUICIO / CONCEPTOS REFERENCIALES */
    CB.AnioJuicio,
    CB.NumeroJuicio,
    CB.ConceptoDeudaTituloReferencial,
    CB.ConceptoDeudaCoactivaReferencial,

    CB.DiferenciaValor,

    /* ANTIGÜEDAD */
    CB.AntiguedadAnios,
    CB.RangoAntiguedad,

    /* GEO */
    CB.AGA,
    CB.Parroquia,
    CB.SectorNomenclatura,

    CB.DireccionUbicacion,
    CB.LatitudUbicacion,
    CB.LongitudUbicacion,

    CB.OrigenUbicacion,
    CB.NivelConfianzaUbicacion,
    CB.CalidadUbicacion,

    /* CATASTRO */
    CB.Sector,
    CB.Manzana,
    CB.Lote,
    CB.Division,
    CB.Phv,
    CB.Phh,
    CB.Numero,
    CB.NumeroEstablecimientoSri,

    /* PARETO / CONTRIBUYENTE */
    SG.RankingDeudor,

    SG.ObligacionesContribuyente,
    SG.DeudaTotalContribuyente,
    SG.DeudaCoactivaContribuyente,
    SG.DeudaTituloContribuyente,

    SG.AnioDeudaMasAntigua,
    SG.AnioDeudaMasReciente,

    SG.ParticipacionIndividualPct,
    SG.ParticipacionAcumuladaPct,

    SG.SegmentoGestion

FROM CarteraBase CB

INNER JOIN Segmentacion SG
    ON CB.IdContribuyente = SG.IdContribuyente

CROSS JOIN CortesFuentes CF;
