/*
 * ============================================================================
 * CONSULTA: titulos de predios urbanos
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Cartera Municipal: Cobranza y Conciliación
 * Página / destino    : TÍTULOS DE PREDIOS
 * Qué responde        : Cartera de predios urbanos al último corte (31 columnas): antigüedad, estado del juicio, rubros actuales, interés, coactiva, costas y saldo de rubros referencial.
 * Bases de origen     : PREDIO_URBANO_DM, CATASTRO_DM, CONTRIBUYENTE_DM, COACTIVA_DM
 * Granularidad        : Una fila por título de predio urbano en el último corte
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/* ============================================================================
   CARTERA PREDIOS URBANOS - POWER BI V10 COMPACTO + FECHA DE CORTE

   Salida (31 columnas, en este orden):
     FechaCorte, AnioVigencia, NumeroTituloUtil, FechaEmision, AntiguedadAnios,
     RangoAntiguedad, EstadoJuicio, CodigoJuicio, NumeroJuicio, Juzgado,
     ReferenciaPredialTecnica, CodigoPredial, Parroquia, Direccion,
     AvaluoPredio, ClasificacionCatastro, NumeroIdentificacionAsociada,
     NombreTitularTitulo, ValorRubrosActuales, EstadoDeuda,
     Rubro01_ImpPredial, Rubro07_SolarNoEdif, Rubro12_Bomberos,
     Rubro13_AseoPublico, Rubro14_Drenaje, Rubro18_CEM, RubroXX_Otros,
     ValorInteres, ValorCoactiva, ValorCostas, SaldoRubrosReferencial

   Reglas de negocio (sin cambios respecto a V9):
     Corte vigente ; IdDimEstadoPredio = 7 ; IdDimEstadoDeuda IN (5, 7, 8)
     Saldo: 5 -> ValorAdicionales
            7 -> ValorAdicionales - Pago1STotalAdicional
            8 -> ValorAdicionales - Pago2STotalAdicional
     NOTA: SaldoRubrosReferencial considera solo rubros. ValorDescuento,
     ValorInteres, ValorCoactiva y ValorCostas se exponen por separado y NO
     alteran el saldo.
     Identificacion: maestro Contribuyente y, si no hay documento valido,
     Deuda.IdentificacionContribuyente (unica y valida).
     Catastro: atributos y clasificacion solo con vinculo catastral validado.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdCorte INT;
DECLARE @FechaCalculo DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @FechaCorte DATETIME2(3);

/*=============================================================================
 0. ULTIMO CORTE OPERATIVO
=============================================================================*/
SELECT TOP (1)
    @IdCorte = f.IdDimFechaCorte
FROM PREDIO_URBANO_DM.PredioUrbano.FactPlanillaPrediosUrbanos AS f
WHERE f.IdDimEstadoPredio = 7
  AND f.IdDimEstadoDeuda IN (5, 7, 8)
ORDER BY f.IdDimFechaCorte DESC;

IF @IdCorte IS NULL
    THROW 51100, 'No existe un corte operativo disponible en PREDIO_URBANO_DM.', 1;

SELECT @FechaCorte = fc.FechaCorte
FROM PREDIO_URBANO_DM.PredioUrbano.DimFechaCorte AS fc
WHERE fc.IdDimFechaCorte = @IdCorte;

DROP TABLE IF EXISTS #CarteraBase;
DROP TABLE IF EXISTS #PredioKeys;
DROP TABLE IF EXISTS #Catastro;
DROP TABLE IF EXISTS #PersonaKeys;
DROP TABLE IF EXISTS #VinculoContribuyente;
DROP TABLE IF EXISTS #ContribuyenteKeys;
DROP TABLE IF EXISTS #Maestro;
DROP TABLE IF EXISTS #JuicioLocal;
DROP TABLE IF EXISTS #JuicioDirectoMap;
DROP TABLE IF EXISTS #FallbackKeys;
DROP TABLE IF EXISTS #JuicioHistoricoCandidatos;
DROP TABLE IF EXISTS #JuicioHistoricoMap;
DROP TABLE IF EXISTS #JuicioMap;

/*=============================================================================
 1. CARTERA DEL CORTE - UNA SOLA LECTURA DE LA FACT (solo columnas necesarias)
=============================================================================*/
SELECT
    f.IdFactPlanillaPrediosUrbanos,
    f.IdDimFechaCorte,
    f.IdDimTipoPredio,
    f.IdDimEstadoDeuda,
    f.IdDimEstadoGeneralJuicio,
    f.IdDimEstadoJuicio,
    f.IdDimJucioCoativo,
    f.AnioVigencia,
    f.TituloCredito1,
    f.TituloCredito2,
    f.FechaEmision,

    p.Sector,
    p.Manzana,
    p.Lote,
    p.Division,
    p.Phv,
    p.Phh,
    p.Numero,

    NombreTitularTitulo = NULLIF(LTRIM(RTRIM(nt.Nombre)), ''),
    NombreClave         = NULLIF(LTRIM(RTRIM(nt.Nombre)), '') COLLATE Latin1_General_CI_AI,

    f.Rubro01_ImpPredial,
    f.Rubro07_SolarNoEdif,
    f.Rubro12_Bomberos,
    f.Rubro13_AseoPublico,
    f.Rubro14_Drenaje,
    f.Rubro18_CEM,
    f.RubroXX_Otros,

    f.ValorAdicionales,          -- fuente oficial del valor actual de rubros
    f.ValorDescuento,
    f.ValorInteres,
    f.ValorCoactiva,
    f.ValorCostas,
    f.Pago1STotalAdicional,      -- solo para saldo en estado 7
    f.Pago2STotalAdicional       -- solo para saldo en estado 8
INTO #CarteraBase
FROM PREDIO_URBANO_DM.PredioUrbano.FactPlanillaPrediosUrbanos AS f
INNER JOIN PREDIO_URBANO_DM.PredioUrbano.DimInfoPredio AS p
    ON p.IdDimInfoPredio = f.IdDimInfoPredio
LEFT JOIN PREDIO_URBANO_DM.PredioUrbano.DimNombreTitulo AS nt
    ON nt.IdDimNombreTitulo = f.IdDimNombreTitulo
WHERE f.IdDimFechaCorte   = @IdCorte
  AND f.IdDimEstadoPredio = 7
  AND f.IdDimEstadoDeuda IN (5, 7, 8)
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_CarteraBase
    ON #CarteraBase (IdFactPlanillaPrediosUrbanos);

CREATE INDEX IX_CarteraBase_Predio
    ON #CarteraBase (Sector, Manzana, Lote, Division, Phv, Phh, Numero)
    INCLUDE (NombreClave);

CREATE INDEX IX_CarteraBase_Juicio
    ON #CarteraBase (IdDimJucioCoativo)
    WHERE IdDimJucioCoativo IS NOT NULL AND IdDimJucioCoativo <> 0;

/*=============================================================================
 2. CATASTRO - SOLO PREDIOS DEL CORTE (codigo predial + clasificacion)
=============================================================================*/
SELECT DISTINCT
    c.Sector, c.Manzana, c.Lote, c.Division, c.Phv, c.Phh
INTO #PredioKeys
FROM #CarteraBase AS c;

CREATE UNIQUE CLUSTERED INDEX CIX_PredioKeys
    ON #PredioKeys (Sector, Manzana, Lote, Division, Phv, Phh);

SELECT
    c.Sector,
    c.Manzana,
    c.Lote,
    c.Division,
    c.Phv,
    c.Phh,
    COUNT_BIG(*)                                      AS CoincidenciasCatastro,
    MAX(c.CodigoPredial   COLLATE DATABASE_DEFAULT)   AS CodigoPredial,
    MAX(c.IdClasificacion COLLATE DATABASE_DEFAULT)   AS ClasificacionCatastro,
    MAX(c.Parroquia       COLLATE DATABASE_DEFAULT)   AS Parroquia,
    MAX(c.Direccion       COLLATE DATABASE_DEFAULT)   AS Direccion,
    MAX(c.AvaluoPredio)                               AS AvaluoPredio
INTO #Catastro
FROM CATASTRO_DM.PrediosUrbanos.PrediosUrbanos AS c
INNER JOIN #PredioKeys AS k
    ON  k.Sector   = c.Sector
    AND k.Manzana  = c.Manzana
    AND k.Lote     = c.Lote
    AND k.Division = c.Division
    AND k.Phv      = c.Phv
    AND k.Phh      = c.Phh
GROUP BY
    c.Sector, c.Manzana, c.Lote, c.Division, c.Phv, c.Phh
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_Catastro
    ON #Catastro (Sector, Manzana, Lote, Division, Phv, Phh);

/*=============================================================================
 3. IDENTIFICACION REFERENCIAL (predio + nombre -> contribuyente unico)
=============================================================================*/
SELECT DISTINCT
    c.Sector, c.Manzana, c.Lote, c.Division, c.Phv, c.Phh, c.Numero,
    c.NombreClave
INTO #PersonaKeys
FROM #CarteraBase AS c
WHERE c.NombreClave IS NOT NULL;

CREATE INDEX IX_PersonaKeys_Predio
    ON #PersonaKeys (Sector, Manzana, Lote, Division, Phv, Phh, Numero)
    INCLUDE (NombreClave);

SELECT
    k.Sector, k.Manzana, k.Lote, k.Division, k.Phv, k.Phh, k.Numero,
    k.NombreClave,
    COUNT(DISTINCT d.IdContribuyente) AS CantidadContribuyentes,
    MAX(d.IdContribuyente)            AS IdContribuyenteCandidato,
    COUNT(DISTINCT ident.IdentificacionDeuda) AS CantidadIdentificaciones,
    MAX(ident.IdentificacionDeuda)            AS IdentificacionDeuda
INTO #VinculoContribuyente
FROM #PersonaKeys AS k
INNER JOIN CONTRIBUYENTE_DM.dbo.Deuda AS d
    ON  d.Sector   = k.Sector
    AND d.Manzana  = k.Manzana
    AND d.Lote     = k.Lote
    AND d.Division = k.Division
    AND d.Phv      = k.Phv
    AND d.Phh      = k.Phh
    AND d.Numero   = k.Numero
    AND LTRIM(RTRIM(d.NombreContribuyente)) COLLATE Latin1_General_CI_AI
        = k.NombreClave COLLATE Latin1_General_CI_AI
CROSS APPLY
(
    SELECT IdentificacionDeuda =
        CASE
            WHEN LEN(LTRIM(RTRIM(d.IdentificacionContribuyente))) IN (10, 13)
             AND LTRIM(RTRIM(d.IdentificacionContribuyente)) NOT LIKE '%[^0-9]%'
             AND LTRIM(RTRIM(d.IdentificacionContribuyente)) LIKE '%[1-9]%'
                THEN LTRIM(RTRIM(d.IdentificacionContribuyente))
        END
) AS ident
WHERE d.TipoDeuda COLLATE Latin1_General_CI_AI = 'PREDIOS URBANOS'
  AND d.IdContribuyente IS NOT NULL
GROUP BY
    k.Sector, k.Manzana, k.Lote, k.Division,
    k.Phv, k.Phh, k.Numero, k.NombreClave
OPTION (RECOMPILE);

CREATE INDEX IX_VinculoContribuyente_Predio
    ON #VinculoContribuyente (Sector, Manzana, Lote, Division, Phv, Phh, Numero)
    INCLUDE (NombreClave, CantidadContribuyentes, IdContribuyenteCandidato,
             CantidadIdentificaciones, IdentificacionDeuda);

SELECT DISTINCT
    v.IdContribuyenteCandidato AS IdContribuyente
INTO #ContribuyenteKeys
FROM #VinculoContribuyente AS v
WHERE v.CantidadContribuyentes = 1
  AND v.IdContribuyenteCandidato IS NOT NULL;

CREATE UNIQUE CLUSTERED INDEX CIX_ContribuyenteKeys
    ON #ContribuyenteKeys (IdContribuyente);

SELECT
    m.IdContribuyente,
    COUNT_BIG(*)                                   AS RegistrosMaestro,
    MAX(m.Identificacion COLLATE DATABASE_DEFAULT) AS Identificacion,
    MAX(m.Cedula         COLLATE DATABASE_DEFAULT) AS Cedula,
    MAX(m.Ruc            COLLATE DATABASE_DEFAULT) AS Ruc
INTO #Maestro
FROM CONTRIBUYENTE_DM.dbo.Contribuyente AS m
INNER JOIN #ContribuyenteKeys AS k
    ON k.IdContribuyente = m.IdContribuyente
GROUP BY m.IdContribuyente
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_Maestro
    ON #Maestro (IdContribuyente);

/*=============================================================================
 4. COACTIVA - CRUCE HIBRIDO (solo CodigoJuicio, NumeroJuicio y Juzgado)
    1) Directo por IdDimJucioCoativo cuando conduce a un CodigoJuicio real.
    2) Fallback por predio + AnioVigencia en AniosDeuda, priorizando estado
       coincidente, FechaEstado, FechaIngreso y secuencia mas recientes.
=============================================================================*/

/* 4.1 Referencias directas validas (llaves + codigo/juzgado de PREDIO_URBANO_DM) */
SELECT DISTINCT
    c.IdDimJucioCoativo,
    CodigoJuicioPredio =
        NULLIF(NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(100), j.JuicioCoactivo))), ''), '0'),
    JuzgadoPredio =
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(250), j.Juzgado), ''))))
                 IN ('', 'NO DEFINIDO')
                THEN NULL
            ELSE LTRIM(RTRIM(CONVERT(VARCHAR(250), j.Juzgado)))
        END
INTO #JuicioLocal
FROM #CarteraBase AS c
LEFT JOIN PREDIO_URBANO_DM.PredioUrbano.DimJucioCoativo AS j
    ON j.IdDimJucioCoativo = c.IdDimJucioCoativo
WHERE ISNULL(c.IdDimJucioCoativo, 0) <> 0;

CREATE UNIQUE CLUSTERED INDEX CIX_JuicioLocal
    ON #JuicioLocal (IdDimJucioCoativo);

/* 4.2 Mapa directo */
;WITH DirectoCandidato AS
(
    SELECT
        jl.IdDimJucioCoativo,
        jl.CodigoJuicioPredio,
        jl.JuzgadoPredio,
        jc.NumeroJuicio,
        jc.CodigoJuicio,
        jc.Juzgado,
        RN = ROW_NUMBER() OVER
        (
            PARTITION BY jl.IdDimJucioCoativo
            ORDER BY
                jc.FechaEstado         DESC,
                jc.FechaIngreso        DESC,
                jc.IdSecuenciaJuicio   DESC,
                jc.IdDimJuicioCoactivo DESC
        )
    FROM #JuicioLocal AS jl
    INNER JOIN COACTIVA_DM.JuiciosCoactivos.DimJuicioCoactivo AS jc
        ON jc.CodigoJuicio COLLATE Latin1_General_CI_AI
         = jl.CodigoJuicioPredio COLLATE Latin1_General_CI_AI
    WHERE jl.CodigoJuicioPredio IS NOT NULL
)
SELECT
    d.IdDimJucioCoativo,
    NumeroJuicio =
        COALESCE
        (
            TRY_CONVERT(BIGINT, d.NumeroJuicio),
            TRY_CONVERT(BIGINT, PARSENAME(REPLACE(d.CodigoJuicioPredio, '-', '.'), 1))
        ),
    CodigoJuicio =
        COALESCE
        (
            NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(100), d.CodigoJuicio))), ''),
            d.CodigoJuicioPredio
        ),
    Juzgado =
        COALESCE
        (
            NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(250), d.Juzgado))), ''),
            d.JuzgadoPredio
        )
INTO #JuicioDirectoMap
FROM DirectoCandidato AS d
WHERE d.RN = 1
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_JuicioDirectoMap
    ON #JuicioDirectoMap (IdDimJucioCoativo);

/* 4.3 Llaves de fallback (solo obligaciones sin cruce directo) */
SELECT DISTINCT
    f.Sector, f.Manzana, f.Lote, f.Division, f.Phv, f.Phh, f.Numero,
    f.AnioVigencia,
    f.IdDimEstadoJuicio,
    CodigoPredialCoactiva = CONCAT
    (
        f.Sector, '-', f.Manzana, '-', f.Lote, '-',
        f.Division, '-', f.Phv, '-', f.Phh, '-', f.Numero
    )
INTO #FallbackKeys
FROM #CarteraBase AS f
LEFT JOIN #JuicioDirectoMap AS d
    ON d.IdDimJucioCoativo = f.IdDimJucioCoativo
WHERE d.IdDimJucioCoativo IS NULL
  AND f.AnioVigencia IS NOT NULL;

CREATE UNIQUE CLUSTERED INDEX CIX_FallbackKeys
    ON #FallbackKeys
    (Sector, Manzana, Lote, Division, Phv, Phh, Numero, AnioVigencia, IdDimEstadoJuicio);

/* 4.4 Candidatos historicos por predio + anio en AniosDeuda */
SELECT
    k.Sector, k.Manzana, k.Lote, k.Division, k.Phv, k.Phh, k.Numero,
    k.AnioVigencia,
    k.IdDimEstadoJuicio,

    jc.NumeroJuicio,
    jc.CodigoJuicio,
    jc.Juzgado,

    RN = ROW_NUMBER() OVER
    (
        PARTITION BY
            k.Sector, k.Manzana, k.Lote, k.Division,
            k.Phv, k.Phh, k.Numero,
            k.AnioVigencia, k.IdDimEstadoJuicio
        ORDER BY
            CASE WHEN x.EstadoCoincide = 1 THEN 0 ELSE 1 END,
            jc.FechaEstado         DESC,
            jc.FechaIngreso        DESC,
            jc.IdSecuenciaJuicio   DESC,
            jc.IdDimJuicioCoactivo DESC
    )
INTO #JuicioHistoricoCandidatos
FROM #FallbackKeys AS k
LEFT JOIN PREDIO_URBANO_DM.PredioUrbano.DimEstadoJuicio AS ej
    ON ej.IdDimEstadoJuicio = k.IdDimEstadoJuicio
INNER JOIN COACTIVA_DM.JuiciosCoactivos.DimJuicioCoactivo AS jc
    ON LTRIM(RTRIM(CONVERT(VARCHAR(200), jc.CodigoPredialUrbano)))
           COLLATE Latin1_General_CI_AI
     = k.CodigoPredialCoactiva COLLATE Latin1_General_CI_AI
   AND CHARINDEX
       (
           ',' + CONVERT(VARCHAR(4), k.AnioVigencia) + ',',
           ',' +
           REPLACE
           (
               REPLACE(ISNULL(CONVERT(VARCHAR(1000), jc.AniosDeuda), ''), ' ', ''),
               ';',
               ','
           )
           + ','
       ) > 0
CROSS APPLY
(
    SELECT EstadoCoincide =
        CASE
            WHEN NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(500), ej.EstadoJuicio))), '') IS NOT NULL
             AND LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(500), jc.Estado), '')))
                     COLLATE Latin1_General_CI_AI
                 = LTRIM(RTRIM(CONVERT(VARCHAR(500), ej.EstadoJuicio)))
                     COLLATE Latin1_General_CI_AI
                THEN 1
            ELSE 0
        END
) AS x
OPTION (RECOMPILE);

CREATE INDEX IX_JuicioHistoricoCandidatos_Map
    ON #JuicioHistoricoCandidatos
    (Sector, Manzana, Lote, Division, Phv, Phh, Numero, AnioVigencia, IdDimEstadoJuicio, RN);

/* 4.5 Mapa historico: un juicio por predio/anio/estado */
SELECT
    h.Sector, h.Manzana, h.Lote, h.Division, h.Phv, h.Phh, h.Numero,
    h.AnioVigencia,
    h.IdDimEstadoJuicio,
    h.NumeroJuicio,
    CodigoJuicio = NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(100), h.CodigoJuicio))), ''),
    Juzgado      = NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(250), h.Juzgado))), '')
INTO #JuicioHistoricoMap
FROM #JuicioHistoricoCandidatos AS h
WHERE h.RN = 1
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_JuicioHistoricoMap
    ON #JuicioHistoricoMap
    (Sector, Manzana, Lote, Division, Phv, Phh, Numero, AnioVigencia, IdDimEstadoJuicio);

/* 4.6 Mapa final: una fila por obligacion (ruta directa si existe; si no, historica) */
SELECT
    f.IdFactPlanillaPrediosUrbanos,
    NumeroJuicio = COALESCE(d.NumeroJuicio, h.NumeroJuicio),
    CodigoJuicio = COALESCE(d.CodigoJuicio, h.CodigoJuicio),
    Juzgado      = COALESCE(d.Juzgado,      h.Juzgado)
INTO #JuicioMap
FROM #CarteraBase AS f
LEFT JOIN #JuicioDirectoMap AS d
    ON d.IdDimJucioCoativo = f.IdDimJucioCoativo
LEFT JOIN #JuicioHistoricoMap AS h
    ON  d.IdDimJucioCoativo IS NULL
    AND h.Sector       = f.Sector
    AND h.Manzana      = f.Manzana
    AND h.Lote         = f.Lote
    AND h.Division     = f.Division
    AND h.Phv          = f.Phv
    AND h.Phh          = f.Phh
    AND h.Numero       = f.Numero
    AND h.AnioVigencia = f.AnioVigencia
    AND (
          h.IdDimEstadoJuicio = f.IdDimEstadoJuicio
          OR (h.IdDimEstadoJuicio IS NULL AND f.IdDimEstadoJuicio IS NULL)
        )
OPTION (RECOMPILE);

CREATE UNIQUE CLUSTERED INDEX CIX_JuicioMap
    ON #JuicioMap (IdFactPlanillaPrediosUrbanos);

/*=============================================================================
 5. SALIDA FINAL
=============================================================================*/
SELECT
    /* Corte */
    FechaCorte = @FechaCorte,

    /* Titulo */
    f.AnioVigencia,
    NumeroTituloUtil =
        COALESCE
        (
            NULLIF(NULLIF(LTRIM(RTRIM(f.TituloCredito1)), ''), '-'),
            NULLIF(NULLIF(LTRIM(RTRIM(f.TituloCredito2)), ''), '-')
        ),
    f.FechaEmision,
    AntiguedadAnios = ant.Anios,
    RangoAntiguedad =
        CASE
            WHEN ant.Anios IS NULL THEN 'SIN FECHA DE EMISION'
            WHEN ant.Anios <= 1    THEN '0-1 ANIO'
            WHEN ant.Anios <= 3    THEN '2-3 ANIOS'
            WHEN ant.Anios <= 5    THEN '4-5 ANIOS'
            WHEN ant.Anios <= 10   THEN '6-10 ANIOS'
            ELSE 'MAS DE 10 ANIOS'
        END,

    /* Juicio */
    ej.EstadoJuicio,
    j.CodigoJuicio,
    j.NumeroJuicio,
    j.Juzgado,

    /* Predio y catastro (atributos solo con vinculo catastral validado) */
    ReferenciaPredialTecnica = CONCAT(ref.ReferenciaSeisComponentes, '-', f.Numero),
    CodigoPredial = CASE WHEN cv.EsValido = 1 THEN cat.CodigoPredial END,
    Parroquia     = CASE WHEN cv.EsValido = 1 THEN cat.Parroquia     END,
    Direccion     = CASE WHEN cv.EsValido = 1 THEN cat.Direccion     END,
    AvaluoPredio  = CASE WHEN cv.EsValido = 1 THEN cat.AvaluoPredio  END,
    ClasificacionCatastro =
        CASE
            WHEN cv.EsValido = 1
                THEN COALESCE
                     (
                         NULLIF(LTRIM(RTRIM(cat.ClasificacionCatastro)), ''),
                         'SIN CLASIFICACION REGISTRADA'
                     )
            ELSE 'SIN VINCULO CATASTRAL VALIDADO'
        END,

    /* Contribuyente */
    NumeroIdentificacionAsociada = idn.NumeroId,
    f.NombreTitularTitulo,

    /* Financiero */
    ValorRubrosActuales = CAST(f.ValorAdicionales AS DECIMAL(19,2)),
    ed.EstadoDeuda,
    f.Rubro01_ImpPredial,
    f.Rubro07_SolarNoEdif,
    f.Rubro12_Bomberos,
    f.Rubro13_AseoPublico,
    f.Rubro14_Drenaje,
    f.Rubro18_CEM,
    f.RubroXX_Otros,
    f.ValorInteres,
    f.ValorCoactiva,
    f.ValorCostas,
    SaldoRubrosReferencial =
        CAST
        (
            CASE f.IdDimEstadoDeuda
                WHEN 5 THEN ISNULL(f.ValorAdicionales, 0)
                WHEN 7 THEN ISNULL(f.ValorAdicionales, 0) - ISNULL(f.Pago1STotalAdicional, 0)
                WHEN 8 THEN ISNULL(f.ValorAdicionales, 0) - ISNULL(f.Pago2STotalAdicional, 0)
            END
            AS DECIMAL(19,2)
        )
FROM #CarteraBase AS f
LEFT JOIN PREDIO_URBANO_DM.PredioUrbano.DimEstadoDeuda AS ed
    ON ed.IdDimEstadoDeuda = f.IdDimEstadoDeuda
LEFT JOIN PREDIO_URBANO_DM.PredioUrbano.DimEstadoJuicio AS ej
    ON ej.IdDimEstadoJuicio = f.IdDimEstadoJuicio
LEFT JOIN #JuicioMap AS j
    ON j.IdFactPlanillaPrediosUrbanos = f.IdFactPlanillaPrediosUrbanos
LEFT JOIN #Catastro AS cat
    ON  cat.Sector   = f.Sector
    AND cat.Manzana  = f.Manzana
    AND cat.Lote     = f.Lote
    AND cat.Division = f.Division
    AND cat.Phv      = f.Phv
    AND cat.Phh      = f.Phh
LEFT JOIN #VinculoContribuyente AS vc
    ON  vc.Sector   = f.Sector
    AND vc.Manzana  = f.Manzana
    AND vc.Lote     = f.Lote
    AND vc.Division = f.Division
    AND vc.Phv      = f.Phv
    AND vc.Phh      = f.Phh
    AND vc.Numero   = f.Numero
    AND vc.NombreClave COLLATE Latin1_General_CI_AI
        = f.NombreClave COLLATE Latin1_General_CI_AI
LEFT JOIN #Maestro AS m
    ON  m.IdContribuyente = vc.IdContribuyenteCandidato
    AND vc.CantidadContribuyentes = 1
    AND m.RegistrosMaestro = 1
CROSS APPLY
(
    SELECT ReferenciaSeisComponentes = CONCAT
    (
        f.Sector, '-', f.Manzana, '-', f.Lote, '-',
        f.Division, '-', f.Phv, '-', f.Phh
    )
) AS ref
CROSS APPLY
(
    SELECT EsValido =
        CASE
            WHEN cat.CoincidenciasCatastro = 1
             AND LTRIM(RTRIM(cat.CodigoPredial)) COLLATE DATABASE_DEFAULT
                 = ref.ReferenciaSeisComponentes COLLATE DATABASE_DEFAULT
                THEN 1
            ELSE 0
        END
) AS cv
OUTER APPLY
(
    SELECT
        CedulaValida =
            CASE
                WHEN LEN(LTRIM(RTRIM(m.Cedula))) = 10
                 AND LTRIM(RTRIM(m.Cedula)) NOT LIKE '%[^0-9]%'
                 AND LTRIM(RTRIM(m.Cedula)) LIKE '%[1-9]%'
                    THEN LTRIM(RTRIM(m.Cedula))
            END,
        RucValido =
            CASE
                WHEN LEN(LTRIM(RTRIM(m.Ruc))) = 13
                 AND LTRIM(RTRIM(m.Ruc)) NOT LIKE '%[^0-9]%'
                 AND LTRIM(RTRIM(m.Ruc)) LIKE '%[1-9]%'
                    THEN LTRIM(RTRIM(m.Ruc))
            END,
        IdentificacionValida =
            CASE
                WHEN LEN(LTRIM(RTRIM(m.Identificacion))) IN (10, 13)
                 AND LTRIM(RTRIM(m.Identificacion)) NOT LIKE '%[^0-9]%'
                 AND LTRIM(RTRIM(m.Identificacion)) LIKE '%[1-9]%'
                    THEN LTRIM(RTRIM(m.Identificacion))
            END
) AS doc
CROSS APPLY
(
    SELECT
        NumeroId =
            COALESCE
            (
                doc.IdentificacionValida,
                doc.RucValido,
                doc.CedulaValida,
                CASE WHEN vc.CantidadIdentificaciones = 1 THEN vc.IdentificacionDeuda END
            ),
        DesdeMaestro =
            CASE WHEN COALESCE(doc.IdentificacionValida, doc.RucValido, doc.CedulaValida) IS NOT NULL
                 THEN 1 ELSE 0 END
) AS idn
CROSS APPLY
(
    SELECT Anios =
        CASE WHEN f.FechaEmision IS NULL THEN NULL
             ELSE DATEDIFF(YEAR, f.FechaEmision, @FechaCalculo)
        END
) AS ant
OPTION (RECOMPILE);
