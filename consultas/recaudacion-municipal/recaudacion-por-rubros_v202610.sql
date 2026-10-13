/*
 * ============================================================================
 * CONSULTA: recaudacion por rubros
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Recaudación Municipal: Tablero Ejecutivo
 * Página / destino    : RUBROS y NO TRIBUTARIO
 * Qué responde        : Recaudación por rubros definidos en un catálogo (incluye rubros sin movimiento, con valores en cero). Trata aparte a un contribuyente especial: se depura por RUC y nombre, se excluye a un homónimo y se descartan las anulaciones.
 * Bases de origen     : RECAUDACION_DM: DesgloseCobros (FactCobro, DimContribuyente y catálogos)
 * Granularidad        : Rubro y subtransacción
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Antes de ejecutar: sustituir <RUC_OTECEL> por el RUC del contribuyente especial.
 * ============================================================================
 */

/*==============================================================================
    POWER BI - RECAUDACIÓN POR RUBROS

    VERSIÓN FINAL CORREGIDA
    - Incluye únicamente los rubros definidos.
    - Muestra todos los rubros, tengan o no movimiento.
    - Los rubros sin movimiento quedan con valores en cero.
    - No crea registros manuales TOTAL VTA o TOTAL REGALÍAS.
    - Los subtotales deben configurarse en la matriz de Power BI.
    - No incluye Concepto.
    - No incluye columnas de reversos.
    - Conserva FechaReverso internamente para excluir anulaciones de OTECEL.
    - OTECEL se depura por RUC/nombre y se excluye COTECEL.
    - VTA/21 aparece con dos etiquetas; COMPRA/VENTA se marca como alias.
==============================================================================*/

WITH RubrosBase AS
(
    SELECT
        V.OrdenGrupo,
        V.OrdenRubro,
        V.GrupoRubro,
        V.Rubro,
        V.CodTransaccion,
        V.CodSubTransaccion
    FROM
    (
        VALUES
        /*======================================================================
            RUBROS GENERALES: SE EXPANDEN TODAS SUS SUBTRANSACCIONES
        ======================================================================*/
        (
            1, 1,
            N'GENERAL',
            N'MULTAS JUSTICIA Y VIGILANCIA',
            N'JUS',
            CAST(NULL AS SMALLINT)
        ),
        (
            2, 1,
            N'GENERAL',
            N'BAHÍAS',
            N'SCB',
            CAST(NULL AS SMALLINT)
        ),
        (
            3, 1,
            N'GENERAL',
            N'MERCADOS',
            N'MER',
            CAST(NULL AS SMALLINT)
        ),

        /*======================================================================
            VENTA DE ACTIVOS
        ======================================================================*/
        (
            4, 1,
            N'VTA',
            N'LOTES ALEGRÍA',
            N'VTA',
            CAST(5 AS SMALLINT)
        ),
        (
            4, 2,
            N'VTA',
            N'EXCEDENTE DE TERRENO / COMPRA-VENTA DE TERRENOS',
            N'VTA',
            CAST(21 AS SMALLINT)
        ),
        (
            4, 3,
            N'VTA',
            N'COMPRAVENTA NO HABITACIONAL',
            N'VTA',
            CAST(6 AS SMALLINT)
        ),
        (
            4, 4,
            N'VTA',
            N'SUBASTA MUCHO LOTE REMATE INMUEBLES',
            N'VTA',
            CAST(18 AS SMALLINT)
        ),
        (
            4, 5,
            N'VTA',
            N'SUBASTA VENTA INMUEBLES PUERTO SANTA ANA',
            N'VTA',
            CAST(20 AS SMALLINT)
        ),
        (
            4, 6,
            N'VTA',
            N'SUBASTA PÚBLICA VENTA DE BIENES INMUEBLES',
            N'VTA',
            CAST(35 AS SMALLINT)
        ),
        (
            4, 7,
            N'VTA',
            N'SUBASTA PÚBLICA MUCHO LOTE I',
            N'VTA',
            CAST(37 AS SMALLINT)
        ),
        (
            4, 8,
            N'VTA',
            N'SUBASTA PÚBLICA MI LOTE 2B',
            N'VTA',
            CAST(38 AS SMALLINT)
        ),
        (
            4, 9,
            N'VTA',
            N'SUBASTA PÚBLICA MUCHO LOTE II',
            N'VTA',
            CAST(30 AS SMALLINT)
        ),
        (
            4, 10,
            N'VTA',
            N'SUBASTA PÚBLICA PROYECTO MI LOTE',
            N'VTA',
            CAST(33 AS SMALLINT)
        ),
        (
            4, 11,
            N'VTA',
            N'PLAN HABITACIONAL BOSQUES DEL NORTE 1',
            N'VTA',
            CAST(40 AS SMALLINT)
        ),
        (
            4, 12,
            N'VTA',
            N'PLAN HABITACIONAL BOSQUES DEL NORTE 2',
            N'VTA',
            CAST(43 AS SMALLINT)
        ),
        (
            4, 13,
            N'VTA',
            N'PLAN HABITACIONAL JARDINES DE SINAHI 1',
            N'VTA',
            CAST(36 AS SMALLINT)
        ),
        (
            4, 14,
            N'VTA',
            N'PLAN HABITACIONAL JARDINES DE SINAHI 2',
            N'VTA',
            CAST(39 AS SMALLINT)
        ),
        (
            4, 15,
            N'VTA',
            N'PLAN HABITACIONAL DULCE HOGAR',
            N'VTA',
            CAST(41 AS SMALLINT)
        ),
        (
            4, 16,
            N'VTA',
            N'PLAN HABITACIONAL MI LOTE 1',
            N'VTA',
            CAST(23 AS SMALLINT)
        ),
        (
            4, 17,
            N'VTA',
            N'PLAN HABITACIONAL MI LOTE 2',
            N'VTA',
            CAST(32 AS SMALLINT)
        ),
        (
            4, 18,
            N'VTA',
            N'PLAN HABITACIONAL MUCHO LOTE 1',
            N'VTA',
            CAST(12 AS SMALLINT)
        ),
        (
            4, 19,
            N'VTA',
            N'PLAN HABITACIONAL MUCHO LOTE 2',
            N'VTA',
            CAST(27 AS SMALLINT)
        ),

        /*======================================================================
            OTROS RUBROS
        ======================================================================*/
        (
            5, 1,
            N'GENERAL',
            N'CANON DE ARRENDAMIENTO',
            N'CAT',
            CAST(NULL AS SMALLINT)
        ),
        (
            6, 1,
            N'GENERAL',
            N'REGALÍAS MINERAS',
            N'CAN',
            CAST(3 AS SMALLINT)
        ),
        (
            7, 1,
            N'GENERAL',
            N'DECLARACIÓN CIUDADANA',
            N'PRU',
            CAST(22 AS SMALLINT)
        ),
        (
            8, 1,
            N'GENERAL',
            N'DESECHOS SÓLIDOS',
            N'DSO',
            CAST(NULL AS SMALLINT)
        ),

        /*======================================================================
            REGALÍAS
        ======================================================================*/
        (
            9, 1,
            N'REGALÍAS',
            N'REGALÍA OTECEL',
            N'VAR',
            CAST(35 AS SMALLINT)
        ),
        (
            9, 2,
            N'REGALÍAS',
            N'REGALÍA OTECEL (TÍTULO / CRÉDITO)',
            N'PDP',
            CAST(43 AS SMALLINT)
        ),
        (
            9, 3,
            N'REGALÍAS',
            N'REGALÍA NEADCO',
            N'PDP',
            CAST(19 AS SMALLINT)
        ),
        (
            9, 4,
            N'REGALÍAS',
            N'REGALÍA CONSULADO DE ESPAÑA DE GUAYAQUIL',
            N'PDP',
            CAST(42 AS SMALLINT)
        ),
        (
            9, 5,
            N'REGALÍAS',
            N'REGALÍA RIANXEIRA (WESTERN UNION)',
            N'PDP',
            CAST(12 AS SMALLINT)
        ),
        (
            9, 6,
            N'REGALÍAS',
            N'REGALÍA LA PERLA',
            N'PER',
            CAST(NULL AS SMALLINT)
        ),
        (
            9, 7,
            N'REGALÍAS',
            N'REGALÍA RESTBAR',
            N'RBA',
            CAST(NULL AS SMALLINT)
        ),
        (
            9, 8,
            N'REGALÍAS',
            N'REGALÍA KWANG MIM KIM (EDIFICIO VERDE)',
            N'REV',
            CAST(NULL AS SMALLINT)
        ),
        (
            9, 9,
            N'REGALÍAS',
            N'REGALÍA PROCAFECOL ECUADOR (JUAN VALDEZ)',
            N'RPE',
            CAST(NULL AS SMALLINT)
        ),
        (
            9, 10,
            N'REGALÍAS',
            N'REGALÍA TOPPARKING (PARQUEADEROS SAMANES)',
            N'RPS',
            CAST(NULL AS SMALLINT)
        ),

        /*======================================================================
            MUSEO DEL CACAO
        ======================================================================*/
        (
            10, 1,
            N'GENERAL',
            N'ARRIENDO MUSEO DEL CACAO',
            N'MNC',
            CAST(NULL AS SMALLINT)
        )
    ) AS V
    (
        OrdenGrupo,
        OrdenRubro,
        GrupoRubro,
        Rubro,
        CodTransaccion,
        CodSubTransaccion
    )
),

/*==============================================================================
    SUBTRANSACCIONES VIA SOLICITADAS
==============================================================================*/
ViaCodigos AS
(
    SELECT
        V.OrdenRubro,
        CAST(V.CodSubTransaccion AS SMALLINT)
            AS CodSubTransaccion
    FROM
    (
        VALUES
        (1, 11),
        (2, 12),
        (3, 13),
        (4, 21),
        (5, 22),
        (6, 31),
        (7, 32),
        (8, 41),
        (9, 42),
        (10, 43),
        (11, 44),
        (12, 45),
        (13, 51),
        (14, 52),
        (15, 53),
        (16, 54),
        (17, 91),
        (18, 92),
        (19, 93),
        (20, 94),
        (21, 95),
        (22, 96),
        (23, 99),
        (24, 204),
        (25, 205),
        (26, 206),
        (27, 240),
        (28, 290),
        (29, 300),
        (30, 331),
        (31, 340),
        (32, 341),
        (33, 342),
        (34, 343),
        (35, 344),
        (36, 412),
        (37, 432),
        (38, 433),
        (39, 434),
        (40, 441),
        (41, 501),
        (42, 502),
        (43, 503),
        (44, 504),
        (45, 505),
        (46, 506)
    ) AS V
    (
        OrdenRubro,
        CodSubTransaccion
    )
),

Rubros AS
(
    SELECT
        RB.OrdenGrupo,
        RB.OrdenRubro,
        RB.GrupoRubro,
        RB.Rubro,
        RB.CodTransaccion,
        RB.CodSubTransaccion
    FROM RubrosBase AS RB

    UNION ALL

    SELECT
        11 AS OrdenGrupo,
        VC.OrdenRubro,
        N'VÍA PÚBLICA' AS GrupoRubro,

        CONCAT
        (
            N'VÍA PÚBLICA NO TRIBUTARIA - ',
            CONVERT
            (
                NVARCHAR(10),
                VC.CodSubTransaccion
            )
        ) AS Rubro,

        N'VIA' AS CodTransaccion,
        VC.CodSubTransaccion

    FROM ViaCodigos AS VC
),

/*==============================================================================
    CLASIFICACIÓN POR TRANSACCIÓN Y SUBTRANSACCIÓN
==============================================================================*/
ClasificacionSubtransaccion AS
(
    SELECT
        UPPER
        (
            LTRIM
            (
                RTRIM(DT.CodTransaccion)
            )
        ) AS CodTransaccion,

        DT.CodSubTransaccion,

        CASE
            WHEN COUNT
            (
                DISTINCT NULLIF
                (
                    LTRIM(RTRIM(DT.TipoCuenta)),
                    N''
                )
            ) = 0
                THEN N'SIN CLASIFICAR'

            WHEN COUNT
            (
                DISTINCT NULLIF
                (
                    LTRIM(RTRIM(DT.TipoCuenta)),
                    N''
                )
            ) = 1
                THEN MAX
                (
                    NULLIF
                    (
                        LTRIM(RTRIM(DT.TipoCuenta)),
                        N''
                    )
                )

            ELSE N'MIXTO'
        END AS TipoCuenta

    FROM
        [RECAUDACION_DM].[CarteraVencida].[DimTransaccion] AS DT

    GROUP BY
        UPPER
        (
            LTRIM
            (
                RTRIM(DT.CodTransaccion)
            )
        ),
        DT.CodSubTransaccion
),

ClasificacionTransaccion AS
(
    SELECT
        UPPER
        (
            LTRIM
            (
                RTRIM(DT.CodTransaccion)
            )
        ) AS CodTransaccion,

        CASE
            WHEN COUNT
            (
                DISTINCT NULLIF
                (
                    LTRIM(RTRIM(DT.TipoCuenta)),
                    N''
                )
            ) = 0
                THEN N'SIN CLASIFICAR'

            WHEN COUNT
            (
                DISTINCT NULLIF
                (
                    LTRIM(RTRIM(DT.TipoCuenta)),
                    N''
                )
            ) = 1
                THEN MAX
                (
                    NULLIF
                    (
                        LTRIM(RTRIM(DT.TipoCuenta)),
                        N''
                    )
                )

            ELSE N'MIXTO'
        END AS TipoCuenta

    FROM
        [RECAUDACION_DM].[CarteraVencida].[DimTransaccion] AS DT

    GROUP BY
        UPPER
        (
            LTRIM
            (
                RTRIM(DT.CodTransaccion)
            )
        )
),

/*==============================================================================
    MAPEO DE TODAS LAS SUBTRANSACCIONES DE RECAUDACIÓN

    Cuando el catálogo tiene NULL, incluye cada subtransacción disponible.
    Cuando tiene un código, incluye solamente dicha subtransacción.
==============================================================================*/
MapeoRecaudacion AS
(
    SELECT DISTINCT
        R.OrdenGrupo,
        R.OrdenRubro,
        R.GrupoRubro,
        R.Rubro,

        R.CodTransaccion,

        R.CodSubTransaccion
            AS CodSubTransaccionSolicitada,

        TD.CodSubTransaccion
            AS CodSubTransaccionReal,

        TD.IdDimTransaccionDesglose,

        TD.Transaccion
            AS TransaccionDW,

        TD.SubTransaccion
            AS SubTransaccionDW,

        COALESCE
        (
            CS.TipoCuenta,
            CT.TipoCuenta,
            N'SIN CLASIFICAR'
        ) AS TipoCuenta

    FROM Rubros AS R

    INNER JOIN
        [RECAUDACION_DM].[RecaudacionNeta].[DimTransaccionDesglose] AS TD
        ON UPPER
           (
               LTRIM
               (
                   RTRIM(TD.CodTransaccion)
               )
           ) COLLATE DATABASE_DEFAULT
           =
           R.CodTransaccion COLLATE DATABASE_DEFAULT

       AND
       (
            R.CodSubTransaccion IS NULL
            OR TD.CodSubTransaccion = R.CodSubTransaccion
       )

    LEFT JOIN ClasificacionSubtransaccion AS CS
        ON CS.CodTransaccion COLLATE DATABASE_DEFAULT
           =
           UPPER
           (
               LTRIM
               (
                   RTRIM(TD.CodTransaccion)
               )
           ) COLLATE DATABASE_DEFAULT

       AND CS.CodSubTransaccion =
           TD.CodSubTransaccion

    LEFT JOIN ClasificacionTransaccion AS CT
        ON CT.CodTransaccion COLLATE DATABASE_DEFAULT
           =
           UPPER
           (
               LTRIM
               (
                   RTRIM(TD.CodTransaccion)
               )
           ) COLLATE DATABASE_DEFAULT
),


/*==============================================================================
    CONTRIBUYENTES OTECEL DEPURADOS
==============================================================================*/
OtecelContribuyentes AS
(
    SELECT DISTINCT
        C.IdDimContribuyente
    FROM [RECAUDACION_DM].[DesgloseCobros].[DimContribuyente] AS C
    CROSS APPLY
    (
        SELECT
            UPPER
            (
                REPLACE
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE
                            (
                                LTRIM(RTRIM(ISNULL(C.NombreContribuyente, N''))),
                                N'.', N''
                            ),
                            N',', N''
                        ),
                        N'-', N''
                    ),
                    N' ', N''
                )
            ) AS NombreNormalizado,
            REPLACE
            (
                REPLACE
                (
                    REPLACE(ISNULL(C.CedulaRuc, N''), N'-', N''),
                    N' ', N''
                ),
                N'.', N''
            ) AS IdentificacionNormalizada
    ) AS N
    WHERE
        N.IdentificacionNormalizada = N'<RUC_OTECEL>'
        OR
        (
            N.NombreNormalizado LIKE N'%OTECEL%'
            AND N.NombreNormalizado NOT LIKE N'%COTECEL%'
        )
),

/*==============================================================================
    COMPROBANTES OTECEL
==============================================================================*/
OtecelCobros AS
(
    SELECT
        C.IdFactCobro,
        C.IdDimFechaCobro,
        C.IdDimContribuyente,
        C.IdCobro,
        C.IdLiquidacion,
        C.TotalEfectivo,
        C.TotalCheque,
        C.TotalTarjeta,
        C.TotalNotaCredito,
        C.TotalExterno,
        C.TotalTransferencia,
        C.Total,
        C.FechaReverso
    FROM [RECAUDACION_DM].[DesgloseCobros].[FactCobro] AS C
    INNER JOIN OtecelContribuyentes AS O
        ON O.IdDimContribuyente = C.IdDimContribuyente
),

/*==============================================================================
    TOTAL DEL DETALLE POR COMPROBANTE OTECEL
==============================================================================*/
OtecelTotalDetalle AS
(
    SELECT
        DC.IdFactCobro,
        SUM(CONVERT(DECIMAL(38,6), ISNULL(DC.Valor, 0)))
            AS TotalDetalleComprobante
    FROM [RECAUDACION_DM].[DesgloseCobros].[FactDesgloseCobro] AS DC
    INNER JOIN OtecelCobros AS OC
        ON OC.IdFactCobro = DC.IdFactCobro
    GROUP BY
        DC.IdFactCobro
),

/*==============================================================================
    DETALLE EXCLUSIVO DE OTECEL: VAR/35 Y PDP/43
==============================================================================*/
OtecelDetalle AS
(
    SELECT
        OC.IdFactCobro,
        OC.IdCobro,
        OC.IdLiquidacion,
        FC.FechaCobro,
        UPPER(LTRIM(RTRIM(TD.CodTransaccion))) AS CodTransaccion,
        TD.CodSubTransaccion,
        TD.Transaccion AS TransaccionDW,
        TD.SubTransaccion AS SubTransaccionDW,
        CONVERT(DECIMAL(38,6), ISNULL(DC.Valor, 0)) AS ValorRubro,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalEfectivo, 0) * A.FactorDistribucion
        ) AS ValorEfectivoAsignado,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalCheque, 0) * A.FactorDistribucion
        ) AS ValorChequeAsignado,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalExterno, 0) * A.FactorDistribucion
        ) AS ValorBanRedAsignado,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalTarjeta, 0) * A.FactorDistribucion
        ) AS ValorTarjetaAsignado,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalTransferencia, 0) * A.FactorDistribucion
        ) AS ValorSPIAsignado,

        CONVERT
        (
            DECIMAL(38,6),
            ISNULL(OC.TotalNotaCredito, 0) * A.FactorDistribucion
        ) AS ValorNotaCreditoAsignado,
        OC.FechaReverso

    FROM OtecelCobros AS OC
    INNER JOIN [RECAUDACION_DM].[DesgloseCobros].[DimFechaCobro] AS FC
        ON FC.IdDimFechaCobro = OC.IdDimFechaCobro
    INNER JOIN [RECAUDACION_DM].[DesgloseCobros].[FactDesgloseCobro] AS DC
        ON DC.IdFactCobro = OC.IdFactCobro
    INNER JOIN OtecelTotalDetalle AS OT
        ON OT.IdFactCobro = OC.IdFactCobro
    INNER JOIN [RECAUDACION_DM].[DesgloseCobros].[DimTransaccionDesglose] AS TD
        ON TD.IdDimTransaccionDesglose = DC.IdDimTransaccionDesglose
    CROSS APPLY
    (
        SELECT
            CASE
                WHEN ISNULL(OT.TotalDetalleComprobante, 0) <> 0
                    THEN
                        CONVERT(DECIMAL(38,12), ISNULL(DC.Valor, 0))
                        /
                        NULLIF
                        (
                            CONVERT(DECIMAL(38,12), OT.TotalDetalleComprobante),
                            0
                        )
                ELSE CONVERT(DECIMAL(38,12), 0)
            END AS FactorDistribucion
    ) AS A
    WHERE
        FC.FechaCobro IS NOT NULL
        AND
        (
            (
                UPPER(LTRIM(RTRIM(TD.CodTransaccion))) = N'VAR'
                AND TD.CodSubTransaccion = 35
            )
            OR
            (
                UPPER(LTRIM(RTRIM(TD.CodTransaccion))) = N'PDP'
                AND TD.CodSubTransaccion = 43
            )
        )
),

/*==============================================================================
    RECAUDACIÓN GENERAL: EXCLUYE LOS DOS CÓDIGOS GENÉRICOS DE OTECEL
==============================================================================*/
RecaudacionGeneral AS
(
    SELECT
        YEAR(FC.FechaCobro) AS AnioRecaudacion,
        MONTH(FC.FechaCobro) AS MesNumero,
        MR.OrdenGrupo,
        MR.OrdenRubro,
        MR.GrupoRubro,
        MR.Rubro,
        MR.CodTransaccion,
        MR.CodSubTransaccionSolicitada,
        MR.CodSubTransaccionReal,
        MR.TipoCuenta,
        MAX(MR.TransaccionDW) AS TransaccionDW,
        MAX(MR.SubTransaccionDW) AS SubTransaccionDW,
        COUNT_BIG(*) AS CantidadFilasDW,
        SUM(CONVERT(BIGINT, ISNULL(F.Cantidad, 0))) AS CantidadOperaciones,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorEfectivo, 0))) AS ValorEfectivo,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorCheque, 0))) AS ValorCheque,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorBanRed, 0))) AS ValorBanRed,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorTarjetaCredito, 0))) AS ValorTarjetaCredito,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorSpi, 0))) AS ValorSPI,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorNotaCredito, 0))) AS ValorNotaCredito,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorIngreso, 0))) AS ValorIngreso,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.[Valor Sin NC], 0))) AS ValorSinNotaCredito,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.[Valor en NC], 0))) AS ValorEnNotaCredito,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.[Valor Fondos de Terceros], 0))) AS ValorFondosTerceros,
        SUM(CONVERT(DECIMAL(38,2), ISNULL(F.ValorTotal, 0))) AS ValorRecaudado
    FROM [RECAUDACION_DM].[RecaudacionNeta].[FactDesgloseCobroTransaccion] AS F
    INNER JOIN [RECAUDACION_DM].[RecaudacionNeta].[DimFechaCobro] AS FC
        ON FC.IdDimFechaCobro = F.IdDimFechaCobro
    INNER JOIN MapeoRecaudacion AS MR
        ON MR.IdDimTransaccionDesglose = F.IdDimTransaccionDesglose
    WHERE
        FC.FechaCobro IS NOT NULL
        AND NOT
        (
            (MR.CodTransaccion = N'VAR' AND MR.CodSubTransaccionReal = 35)
            OR
            (MR.CodTransaccion = N'PDP' AND MR.CodSubTransaccionReal = 43)
        )
    GROUP BY
        YEAR(FC.FechaCobro),
        MONTH(FC.FechaCobro),
        MR.OrdenGrupo,
        MR.OrdenRubro,
        MR.GrupoRubro,
        MR.Rubro,
        MR.CodTransaccion,
        MR.CodSubTransaccionSolicitada,
        MR.CodSubTransaccionReal,
        MR.TipoCuenta
),

/*==============================================================================
    RECAUDACIÓN EXCLUSIVA DE OTECEL
==============================================================================*/
RecaudacionOtecel AS
(
    SELECT
        YEAR(O.FechaCobro) AS AnioRecaudacion,
        MONTH(O.FechaCobro) AS MesNumero,
        9 AS OrdenGrupo,
        CASE WHEN O.CodTransaccion = N'VAR' THEN 1 ELSE 2 END AS OrdenRubro,
        N'REGALÍAS' AS GrupoRubro,
        CASE
            WHEN O.CodTransaccion = N'VAR' THEN N'REGALÍA OTECEL'
            ELSE N'REGALÍA OTECEL (TÍTULO / CRÉDITO)'
        END AS Rubro,
        O.CodTransaccion,
        O.CodSubTransaccion AS CodSubTransaccionSolicitada,
        O.CodSubTransaccion AS CodSubTransaccionReal,
        N'NO TRIBUTARIO' AS TipoCuenta,
        MAX(O.TransaccionDW) AS TransaccionDW,
        MAX(O.SubTransaccionDW) AS SubTransaccionDW,
        SUM
        (
            CASE
                WHEN O.FechaReverso IS NULL THEN CONVERT(BIGINT, 1)
                ELSE CONVERT(BIGINT, 0)
            END
        ) AS CantidadFilasDW,
        COUNT
        (
            DISTINCT CASE
                WHEN O.FechaReverso IS NULL THEN O.IdFactCobro
            END
        ) AS CantidadOperaciones,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorEfectivoAsignado ELSE 0 END) AS ValorEfectivo,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorChequeAsignado ELSE 0 END) AS ValorCheque,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorBanRedAsignado ELSE 0 END) AS ValorBanRed,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorTarjetaAsignado ELSE 0 END) AS ValorTarjetaCredito,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorSPIAsignado ELSE 0 END) AS ValorSPI,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorNotaCreditoAsignado ELSE 0 END) AS ValorNotaCredito,
        SUM
        (
            CASE
                WHEN O.FechaReverso IS NULL
                    THEN O.ValorRubro - O.ValorNotaCreditoAsignado
                ELSE 0
            END
        ) AS ValorIngreso,
        SUM
        (
            CASE
                WHEN O.FechaReverso IS NULL
                    THEN O.ValorRubro - O.ValorNotaCreditoAsignado
                ELSE 0
            END
        ) AS ValorSinNotaCredito,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorNotaCreditoAsignado ELSE 0 END) AS ValorEnNotaCredito,
        CONVERT(DECIMAL(38,2), 0) AS ValorFondosTerceros,
        SUM(CASE WHEN O.FechaReverso IS NULL THEN O.ValorRubro ELSE 0 END) AS ValorRecaudado
    FROM OtecelDetalle AS O
    GROUP BY
        YEAR(O.FechaCobro),
        MONTH(O.FechaCobro),
        O.CodTransaccion,
        O.CodSubTransaccion
),

RecaudacionPowerBI AS
(
    SELECT
        AnioRecaudacion,
        MesNumero,
        OrdenGrupo,
        OrdenRubro,
        GrupoRubro,
        Rubro,
        CodTransaccion,
        CodSubTransaccionSolicitada,
        CodSubTransaccionReal,
        TipoCuenta,
        TransaccionDW,
        SubTransaccionDW,
        CantidadFilasDW,
        CantidadOperaciones,
        ValorEfectivo,
        ValorCheque,
        ValorBanRed,
        ValorTarjetaCredito,
        ValorSPI,
        ValorNotaCredito,
        ValorIngreso,
        ValorSinNotaCredito,
        ValorEnNotaCredito,
        ValorFondosTerceros,
        ValorRecaudado
    FROM RecaudacionGeneral

    UNION ALL

    SELECT
        AnioRecaudacion,
        MesNumero,
        OrdenGrupo,
        OrdenRubro,
        GrupoRubro,
        Rubro,
        CodTransaccion,
        CodSubTransaccionSolicitada,
        CodSubTransaccionReal,
        TipoCuenta,
        TransaccionDW,
        SubTransaccionDW,
        CantidadFilasDW,
        CantidadOperaciones,
        ValorEfectivo,
        ValorCheque,
        ValorBanRed,
        ValorTarjetaCredito,
        ValorSPI,
        ValorNotaCredito,
        ValorIngreso,
        ValorSinNotaCredito,
        ValorEnNotaCredito,
        ValorFondosTerceros,
        ValorRecaudado
    FROM RecaudacionOtecel
),

/*==============================================================================
    MAPEO VISUAL ÚNICO POR TRANSACCIÓN Y SUBTRANSACCIÓN
==============================================================================*/
MapeoVisual AS
(
    SELECT
        MR.CodTransaccion,
        MR.CodSubTransaccionSolicitada,
        MR.CodSubTransaccionReal,
        MAX(MR.TransaccionDW) AS TransaccionDW,
        MAX(MR.SubTransaccionDW) AS SubTransaccionDW,
        MAX(MR.TipoCuenta) AS TipoCuenta
    FROM MapeoRecaudacion AS MR
    GROUP BY
        MR.CodTransaccion,
        MR.CodSubTransaccionSolicitada,
        MR.CodSubTransaccionReal
),

/*==============================================================================
    CATÁLOGO VISUAL

    VTA/21 aparece con dos etiquetas porque así fue solicitado. Ambas etiquetas
    comparten la misma combinación financiera. EsAliasCodigo permite evitar que
    se duplique en medidas de totales.
==============================================================================*/
CatalogoVisual AS
(
    SELECT
        CASE
            WHEN R.CodTransaccion = N'VTA'
             AND R.OrdenRubro >= 3
                THEN R.OrdenRubro + 1
            ELSE R.OrdenRubro
        END AS OrdenRubro,

        R.OrdenGrupo,
        R.GrupoRubro,
        R.Rubro,
        R.CodTransaccion,
        R.CodSubTransaccion,
        CAST(0 AS BIT) AS EsAliasCodigo,
        CAST(1 AS BIT) AS IncluirEnTotal
    FROM Rubros AS R
    WHERE NOT
    (
        R.CodTransaccion = N'VTA'
        AND R.CodSubTransaccion = 21
    )

    UNION ALL

    SELECT
        2 AS OrdenRubro,
        4 AS OrdenGrupo,
        N'VTA' AS GrupoRubro,
        N'EXCEDENTE DE TERRENO' AS Rubro,
        N'VTA' AS CodTransaccion,
        CAST(21 AS SMALLINT) AS CodSubTransaccion,
        CAST(0 AS BIT) AS EsAliasCodigo,
        CAST(1 AS BIT) AS IncluirEnTotal

    UNION ALL

    SELECT
        3 AS OrdenRubro,
        4 AS OrdenGrupo,
        N'VTA' AS GrupoRubro,
        N'COMPRA/VENTA DE TERRENOS' AS Rubro,
        N'VTA' AS CodTransaccion,
        CAST(21 AS SMALLINT) AS CodSubTransaccion,
        CAST(1 AS BIT) AS EsAliasCodigo,
        CAST(0 AS BIT) AS IncluirEnTotal
),

/*==============================================================================
    EXPANSIÓN DEL CATÁLOGO VISUAL

    Los códigos con subtransacción NULL muestran todas las subtransacciones
    existentes en la dimensión. Los códigos específicos conservan su código.
==============================================================================*/
CatalogoVisualExpandido AS
(
    SELECT DISTINCT
        CV.OrdenGrupo,
        CV.OrdenRubro,
        CV.GrupoRubro,
        CV.Rubro,
        CV.CodTransaccion,
        CV.CodSubTransaccion AS CodSubTransaccionSolicitada,

        COALESCE
        (
            MV.CodSubTransaccionReal,
            CV.CodSubTransaccion
        ) AS CodSubTransaccionReal,

        COALESCE
        (
            MV.TipoCuenta,
            CASE
                WHEN CV.CodTransaccion IN (N'VAR', N'PDP')
                 AND CV.CodSubTransaccion IN (35, 43)
                    THEN N'NO TRIBUTARIO'
                ELSE N'SIN CLASIFICAR'
            END
        ) AS TipoCuenta,

        MV.TransaccionDW,
        MV.SubTransaccionDW,
        CV.EsAliasCodigo,
        CV.IncluirEnTotal

    FROM CatalogoVisual AS CV

    LEFT JOIN MapeoVisual AS MV
        ON MV.CodTransaccion COLLATE DATABASE_DEFAULT
           =
           CV.CodTransaccion COLLATE DATABASE_DEFAULT

       AND
       (
            (
                CV.CodSubTransaccion IS NULL
                AND MV.CodSubTransaccionSolicitada IS NULL
            )

            OR MV.CodSubTransaccionReal =
               CV.CodSubTransaccion
       )
),

/*==============================================================================
    PERIODOS PARA POWER BI

    Genera los 12 meses de cada año existente en la dimensión, hasta el mes
    actual. Esto permite mostrar los rubros sin movimiento con valor cero.
==============================================================================*/
Anios AS
(
    SELECT DISTINCT
        YEAR(FC.FechaCobro) AS AnioRecaudacion
    FROM
        [RECAUDACION_DM].[RecaudacionNeta].[DimFechaCobro] AS FC
    WHERE
        FC.FechaCobro IS NOT NULL
        AND YEAR(FC.FechaCobro) BETWEEN 2000 AND YEAR(GETDATE())
),

Meses AS
(
    SELECT MesNumero
    FROM
    (
        VALUES
        (1), (2), (3), (4), (5), (6),
        (7), (8), (9), (10), (11), (12)
    ) AS M(MesNumero)
),

Periodos AS
(
    SELECT
        A.AnioRecaudacion,
        M.MesNumero,
        DATEFROMPARTS
        (
            A.AnioRecaudacion,
            M.MesNumero,
            1
        ) AS FechaPeriodo
    FROM Anios AS A
    CROSS JOIN Meses AS M
    WHERE
        DATEFROMPARTS
        (
            A.AnioRecaudacion,
            M.MesNumero,
            1
        ) <= DATEFROMPARTS
             (
                 YEAR(GETDATE()),
                 MONTH(GETDATE()),
                 1
             )
),

/*==============================================================================
    DETALLE: TODOS LOS RUBROS, TENGAN O NO MOVIMIENTO
==============================================================================*/
DetalleCompleto AS
(
    SELECT
        P.AnioRecaudacion,
        P.MesNumero,
        P.FechaPeriodo,

        CVE.OrdenGrupo,
        CVE.OrdenRubro,
        CVE.GrupoRubro,
        CVE.Rubro,
        CVE.CodTransaccion,
        CVE.CodSubTransaccionSolicitada,
        CVE.CodSubTransaccionReal,
        CVE.TipoCuenta,

        COALESCE
        (
            RP.TransaccionDW,
            CVE.TransaccionDW
        ) AS TransaccionDW,

        COALESCE
        (
            RP.SubTransaccionDW,
            CVE.SubTransaccionDW
        ) AS SubTransaccionDW,

        CVE.EsAliasCodigo,
        CVE.IncluirEnTotal,

        ISNULL(RP.CantidadFilasDW, 0)
            AS CantidadFilasDW,

        ISNULL(RP.CantidadOperaciones, 0)
            AS CantidadOperaciones,

        CAST(ISNULL(RP.ValorEfectivo, 0) AS DECIMAL(38,2))
            AS ValorEfectivo,

        CAST(ISNULL(RP.ValorCheque, 0) AS DECIMAL(38,2))
            AS ValorCheque,

        CAST(ISNULL(RP.ValorBanRed, 0) AS DECIMAL(38,2))
            AS ValorBanRed,

        CAST(ISNULL(RP.ValorTarjetaCredito, 0) AS DECIMAL(38,2))
            AS ValorTarjetaCredito,

        CAST(ISNULL(RP.ValorSPI, 0) AS DECIMAL(38,2))
            AS ValorSPI,

        CAST(ISNULL(RP.ValorNotaCredito, 0) AS DECIMAL(38,2))
            AS ValorNotaCredito,

        CAST(ISNULL(RP.ValorIngreso, 0) AS DECIMAL(38,2))
            AS ValorIngreso,

        CAST(ISNULL(RP.ValorSinNotaCredito, 0) AS DECIMAL(38,2))
            AS ValorSinNotaCredito,

        CAST(ISNULL(RP.ValorEnNotaCredito, 0) AS DECIMAL(38,2))
            AS ValorEnNotaCredito,

        CAST(ISNULL(RP.ValorFondosTerceros, 0) AS DECIMAL(38,2))
            AS ValorFondosTerceros,

        CAST(ISNULL(RP.ValorRecaudado, 0) AS DECIMAL(38,2))
            AS ValorRecaudado

    FROM Periodos AS P

    CROSS JOIN CatalogoVisualExpandido AS CVE

    LEFT JOIN RecaudacionPowerBI AS RP
        ON RP.AnioRecaudacion =
           P.AnioRecaudacion

       AND RP.MesNumero =
           P.MesNumero

       AND RP.CodTransaccion COLLATE DATABASE_DEFAULT =
           CVE.CodTransaccion COLLATE DATABASE_DEFAULT

       AND
       (
            RP.CodSubTransaccionReal =
            CVE.CodSubTransaccionReal

            OR
            (
                RP.CodSubTransaccionReal IS NULL
                AND CVE.CodSubTransaccionReal IS NULL
            )
       )
),

/*==============================================================================
    RESULTADO FINAL: SOLO RUBROS, SIN FILAS MANUALES DE TOTAL
==============================================================================*/
Resultado AS
(
    SELECT
        N'DETALLE' AS TipoFila,
        D.*
    FROM DetalleCompleto AS D
)

SELECT
    R.TipoFila,
    R.AnioRecaudacion,
    R.MesNumero,

    CHOOSE
    (
        R.MesNumero,
        N'ENERO',
        N'FEBRERO',
        N'MARZO',
        N'ABRIL',
        N'MAYO',
        N'JUNIO',
        N'JULIO',
        N'AGOSTO',
        N'SEPTIEMBRE',
        N'OCTUBRE',
        N'NOVIEMBRE',
        N'DICIEMBRE'
    ) AS MesNombre,

    R.FechaPeriodo,

    R.AnioRecaudacion * 100
        + R.MesNumero AS AnioMesOrden,

    R.OrdenGrupo,
    R.OrdenRubro,

    R.OrdenGrupo * 1000
        + R.OrdenRubro AS OrdenVisual,

    R.GrupoRubro,
    R.TipoCuenta,
    R.Rubro,

    R.CodTransaccion
        AS TransaccionEMAS,

    R.CodSubTransaccionSolicitada
        AS SubtransaccionFiltro,

    R.CodSubTransaccionReal
        AS SubtransaccionEMAS,

    CONCAT
    (
        COALESCE(R.CodTransaccion, N'TOTAL'),
        N'|',
        COALESCE
        (
            CONVERT(NVARCHAR(10), R.CodSubTransaccionReal),
            N'SIN_SUB'
        )
    ) AS ClaveSubtransaccion,

    R.TransaccionDW,
    R.SubTransaccionDW,
    R.EsAliasCodigo,
    R.IncluirEnTotal,

    R.CantidadFilasDW,
    R.CantidadOperaciones,
    R.ValorEfectivo,
    R.ValorCheque,
    R.ValorBanRed,
    R.ValorTarjetaCredito,
    R.ValorSPI,
    R.ValorNotaCredito,
    R.ValorIngreso,
    R.ValorSinNotaCredito,
    R.ValorEnNotaCredito,
    R.ValorFondosTerceros,
    R.ValorRecaudado,

    CASE
        WHEN R.CantidadFilasDW = 0
            THEN N'SIN RECAUDACIÓN'

        WHEN R.ValorRecaudado = 0
            THEN N'CON REGISTROS, SIN VALOR'

        ELSE N'CON RECAUDACIÓN'
    END AS EstadoRecaudacion

FROM Resultado AS R;
