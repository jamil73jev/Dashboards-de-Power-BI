/*
 * ============================================================================
 * CONSULTA: recaudacion por puntos de recaudacion
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Recaudación Municipal: Tablero Ejecutivo
 * Página / destino    : PUNTOS DE RECAUDACIÓN
 * Qué responde        : Recaudación por fecha, cajero o recaudador y punto físico de recaudación, de 2023 a 2026. Conserva el punto «NO DEFINIDA» tal como viene en la fuente.
 * Bases de origen     : RECAUDACION_DM: ResumenCobros (FactCobro, DimFechaCobro, DimRecaudador, DimUbicacion)
 * Granularidad        : Fecha + recaudador + ubicación + origen
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/*==============================================================================
 FACT_RECAUDACION_UBICACION_POWERBI
 ------------------------------------------------------------------------------
 OBJETIVO
   Tabla independiente para Power BI orientada al análisis de:
     FECHA -> CAJERO/RECAUDADOR -> PUNTO DE RECAUDACION

 FUENTE
   RECAUDACION_DM.ResumenCobros.FactCobro

 GRANO
   Una fila por:
     FechaCobro
     + IdDimRecaudador
     + IdDimUbicacion
     + Origen

 IMPORTANTE
   - NO se une a DesgloseCobros.
   - NO modifica el total de la tabla principal de recaudación.
   - "NO DEFINIDA" se conserva como dato real de la fuente.
   - Diseñada para Import en Power BI.
==============================================================================*/

WITH Base AS
(
    SELECT
        CAST(FC.FechaCobro AS DATE) AS FechaCobro,

        YEAR(FC.FechaCobro)  AS AnioCobro,
        MONTH(FC.FechaCobro) AS MesCobroNumero,

        CASE MONTH(FC.FechaCobro)
            WHEN 1  THEN 'ENERO'
            WHEN 2  THEN 'FEBRERO'
            WHEN 3  THEN 'MARZO'
            WHEN 4  THEN 'ABRIL'
            WHEN 5  THEN 'MAYO'
            WHEN 6  THEN 'JUNIO'
            WHEN 7  THEN 'JULIO'
            WHEN 8  THEN 'AGOSTO'
            WHEN 9  THEN 'SEPTIEMBRE'
            WHEN 10 THEN 'OCTUBRE'
            WHEN 11 THEN 'NOVIEMBRE'
            WHEN 12 THEN 'DICIEMBRE'
        END AS MesCobroNombre,

        /* Origen del registro de ResumenCobros */
        ISNULL(NULLIF(LTRIM(RTRIM(F.Origen)),''),'SIN_ORIGEN') AS Origen,

        /* Cajero / recaudador */
        F.IdDimRecaudador,
        R.IdRecaudador,

        ISNULL(
            NULLIF(LTRIM(RTRIM(R.EntidadRecaudadora)),''),
            'SIN_ENTIDAD_RECAUDADORA'
        ) AS EntidadRecaudadora,

        ISNULL(
            NULLIF(LTRIM(RTRIM(R.Recaudador)),''),
            'SIN_RECAUDADOR'
        ) AS CajeroRecaudador,

        /* Punto físico */
        F.IdDimUbicacion,
        U.IdUbicacion,

        ISNULL(
            NULLIF(LTRIM(RTRIM(U.Ubicacion)),''),
            'SIN_UBICACION'
        ) AS PuntoRecaudacion,

        CASE
            WHEN ISNULL(U.IdUbicacion,0) = 0
              OR UPPER(LTRIM(RTRIM(ISNULL(U.Ubicacion,'')))) = 'NO DEFINIDA'
                THEN 'NO DEFINIDA'
            ELSE 'DEFINIDA'
        END AS EstadoUbicacion,

        CASE
            WHEN ISNULL(U.IdUbicacion,0) = 0 THEN 99
            ELSE U.IdUbicacion
        END AS OrdenUbicacion,

        /* Métricas de fuente */
        CAST(ISNULL(F.Cantidad,0) AS BIGINT) AS CantidadTransacciones,
        CAST(ISNULL(F.ValorTransaccion,0) AS DECIMAL(38,2)) AS ValorRecaudado

    FROM RECAUDACION_DM.ResumenCobros.FactCobro AS F

    INNER JOIN RECAUDACION_DM.ResumenCobros.DimFechaCobro AS FC
        ON F.IdDimFechaCobro = FC.IdDimFechaCobro

    LEFT JOIN RECAUDACION_DM.ResumenCobros.DimRecaudador AS R
        ON F.IdDimRecaudador = R.IdDimRecaudador

    LEFT JOIN RECAUDACION_DM.ResumenCobros.DimUbicacion AS U
        ON F.IdDimUbicacion = U.IdDimUbicacion

    WHERE FC.FechaCobro >= '20230101'
      AND FC.FechaCobro <  '20270101'
),

UbicacionAgregada AS
(
    SELECT
        FechaCobro,
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,

        Origen,

        IdDimRecaudador,
        IdRecaudador,
        EntidadRecaudadora,
        CajeroRecaudador,

        IdDimUbicacion,
        IdUbicacion,
        PuntoRecaudacion,
        EstadoUbicacion,
        OrdenUbicacion,

        SUM(CantidadTransacciones) AS CantidadTransacciones,

        CAST(
            SUM(ValorRecaudado)
            AS DECIMAL(38,2)
        ) AS ValorRecaudado

    FROM Base

    GROUP BY
        FechaCobro,
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,

        Origen,

        IdDimRecaudador,
        IdRecaudador,
        EntidadRecaudadora,
        CajeroRecaudador,

        IdDimUbicacion,
        IdUbicacion,
        PuntoRecaudacion,
        EstadoUbicacion,
        OrdenUbicacion
)

SELECT
    FechaCobro,
    AnioCobro,
    MesCobroNumero,
    MesCobroNombre,

    Origen,

    IdDimRecaudador,
    IdRecaudador,
    EntidadRecaudadora,
    CajeroRecaudador,

    IdDimUbicacion,
    IdUbicacion,
    PuntoRecaudacion,
    EstadoUbicacion,
    OrdenUbicacion,

    CantidadTransacciones,
    ValorRecaudado

FROM UbicacionAgregada;
