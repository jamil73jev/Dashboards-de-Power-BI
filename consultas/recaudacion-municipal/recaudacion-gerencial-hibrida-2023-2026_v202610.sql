/*
 * ============================================================================
 * CONSULTA: recaudacion gerencial hibrida 2023 2026
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Recaudación Municipal: Tablero Ejecutivo
 * Página / destino    : PRINCIPAL y DESGLOSE
 * Qué responde        : Recaudación comparable de 2023 a 2026 hasta el medio de pago. 2023, 2024 y 2026 salen del desglose de cobros; 2025 sale de la fuente de recaudación neta, que no trae canal.
 * Bases de origen     : RECAUDACION_DM: DesgloseCobros.FactCobro, RecaudacionNeta.FactDesgloseCobroTransaccion
 * Granularidad        : Cobro por rubro y medio de pago, sin cajero ni reversos
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/*==============================================================================
 FACT_RECAUDACION_GERENCIAL_HIBRIDA_2023_2026

 OBJETIVO
 -------
 - Mostrar 2023, 2024, 2025 y 2026 con recaudación real.
 - 2023, 2024 y 2026: RECAUDACION_DM.DesgloseCobros.FactCobro.
 - 2025: RECAUDACION_DM.RecaudacionNeta.FactDesgloseCobroTransaccion.
 - Nivel común comparable: hasta MEDIO DE PAGO.
 - CanalRecaudacion:
      * real para 2023, 2024 y 2026;
      * NO_DISPONIBLE_2025 para 2025, porque esa fuente no trae canal.
 - Sin cajero.
 - Sin reversos.
==============================================================================*/

WITH Parametros AS
(
    SELECT
        CAST('2023-01-01' AS DATE) AS FechaDesde,
        CAST(GETDATE() AS DATE) AS FechaHasta
),

/*==============================================================================
 SPI PARA LA FUENTE TRANSACCIONAL
==============================================================================*/
SPI AS
(
    SELECT
        S.IdFactCobro,
        CAST(SUM(ISNULL(S.Valor,0)) AS DECIMAL(38,6)) AS ValorSPI
    FROM RECAUDACION_DM.DesgloseCobros.FactCobrosConTransaferenciaSpi AS S
    GROUP BY S.IdFactCobro
),

/*==============================================================================
 1. PAGOS 2023 / 2024 / 2026
    2025 se excluye de esta fuente porque no existe en FactCobro.
==============================================================================*/
DetalleBase AS
(
    SELECT
        C.IdFactCobro,
        D.IdFactDesgloseCobro,

        FC.FechaCobro,
        TRY_CONVERT(INT,FC.AnioCobro) AS AnioCobro,
        MONTH(FC.FechaCobro) AS MesCobroNumero,
        FC.MesLetras AS MesCobroNombre,

        LTRIM(RTRIM(TD.CodTransaccion)) AS CodTransaccion,
        LTRIM(RTRIM(TD.Transaccion)) AS Transaccion,

        TD.CodSubTransaccion,
        LTRIM(RTRIM(TD.SubTransaccion)) AS SubTransaccion,

        TD.CodDetalle,
        LTRIM(RTRIM(TD.Detalle)) AS Detalle,

        LTRIM(RTRIM(TD.Tipo)) AS Tipo,

        CONCAT(
            LTRIM(RTRIM(TD.CodTransaccion)), '-',
            RIGHT('000' + CONVERT(VARCHAR(10),TD.CodSubTransaccion),3), '-',
            RIGHT('000' + CONVERT(VARCHAR(10),TD.CodDetalle),3)
        ) AS CodigoRubroCompleto,

        UPPER(CONCAT(
            ISNULL(TD.CodTransaccion,''), ' ',
            ISNULL(TD.Transaccion,''), ' ',
            ISNULL(TD.SubTransaccion,''), ' ',
            ISNULL(TD.Detalle,''), ' ',
            ISNULL(TD.Tipo,'')
        )) AS TextoRubroAnalitico,

        ISNULL(
            NULLIF(LTRIM(RTRIM(CP.CanalDePago)),''),
            'SIN_CANAL'
        ) AS CanalRecaudacion,

        CAST(ISNULL(D.Valor,0) AS DECIMAL(38,6)) AS ValorDetalleEMAS,

        CAST(ISNULL(C.TotalExterno,0) AS DECIMAL(38,6)) AS TotalBanred,
        CAST(ISNULL(C.TotalCheque,0) AS DECIMAL(38,6)) AS TotalCheque,
        CAST(ISNULL(C.TotalTarjeta,0) AS DECIMAL(38,6)) AS TotalTarjetaCredito,
        CAST(ISNULL(C.TotalEfectivo,0) AS DECIMAL(38,6)) AS TotalEfectivo,
        CAST(ISNULL(C.TotalNotaCredito,0) AS DECIMAL(38,6)) AS TotalNotaCredito,

        /* TotalTransferencia NO se muestra como medio adicional.
           Solo respalda SPI cuando la tabla SPI no tiene valor. */
        CAST(
            CASE
                WHEN ABS(ISNULL(S.ValorSPI,0)) > 0.000001
                    THEN ISNULL(S.ValorSPI,0)
                ELSE ISNULL(C.TotalTransferencia,0)
            END
            AS DECIMAL(38,6)
        ) AS TotalSPIConsolidado

    FROM RECAUDACION_DM.DesgloseCobros.FactCobro AS C

    INNER JOIN RECAUDACION_DM.DesgloseCobros.FactDesgloseCobro AS D
        ON D.IdFactCobro = C.IdFactCobro

    INNER JOIN RECAUDACION_DM.DesgloseCobros.DimFechaCobro AS FC
        ON C.IdDimFechaCobro = FC.IdDimFechaCobro

    INNER JOIN RECAUDACION_DM.DesgloseCobros.DimTransaccionDesglose AS TD
        ON D.IdDimTransaccionDesglose = TD.IdDimTransaccionDesglose

    LEFT JOIN RECAUDACION_DM.DesgloseCobros.DimCanalDePago AS CP
        ON C.IdDimCanalDePago = CP.IdDimCanalDePago

    LEFT JOIN SPI AS S
        ON S.IdFactCobro = C.IdFactCobro

    CROSS JOIN Parametros AS P

    WHERE UPPER(LTRIM(RTRIM(C.Estado))) = 'PAGO'
      AND FC.FechaCobro >= P.FechaDesde
      AND FC.FechaCobro < DATEADD(DAY,1,P.FechaHasta)
      AND TRY_CONVERT(INT,FC.AnioCobro) <> 2025
),

ClasificadaActual AS
(
    SELECT
        B.*,

        CASE
            WHEN B.Tipo LIKE '02%Fondos%'
                THEN 'FONDO_TERCERO_CONFIRMADO'

            WHEN B.TextoRubroAnalitico LIKE '%JUNTA DE BENEFICENCIA%'
              OR B.TextoRubroAnalitico LIKE '%BOMBERO%'
              OR B.TextoRubroAnalitico LIKE '%BOMBEROS%'
              OR B.TextoRubroAnalitico LIKE '%CONSEJO PROVINCIAL%'
              OR B.TextoRubroAnalitico LIKE '%ECAPAG%'
              OR B.TextoRubroAnalitico LIKE '%FONDO%TERCERO%'
                THEN 'POSIBLE_FONDO_TERCERO_REVISAR'

            ELSE 'INGRESO_PROPIO_O_MUNICIPAL'
        END AS ClaseIngreso,

        CASE
            WHEN B.Tipo LIKE '02%Fondos%'
                THEN '08_FONDOS_DE_TERCEROS'

            WHEN B.CodTransaccion IN ('PDR','PRU')
              OR B.TextoRubroAnalitico LIKE '%PREDIAL%'
              OR B.TextoRubroAnalitico LIKE '%PREDIO%'
                THEN '01_IMPUESTOS_PREDIALES'

            WHEN B.CodTransaccion IN ('PAT','MIL')
              OR B.TextoRubroAnalitico LIKE '%PATENTE%'
              OR B.TextoRubroAnalitico LIKE '%1.5%'
              OR B.TextoRubroAnalitico LIKE '%ACTIVOS TOTALES%'
                THEN '02_IMPUESTOS_ACTIVIDAD_ECONOMICA'

            WHEN B.CodTransaccion IN ('ALC','PLS','IRV','IVE')
              OR B.TextoRubroAnalitico LIKE '%ALCABALA%'
              OR B.TextoRubroAnalitico LIKE '%PLUSVAL%'
              OR B.TextoRubroAnalitico LIKE '%TRANSFERENCIA DE DOMINIO%'
                THEN '03_IMPUESTOS_TRANSFERENCIA_DOMINIO'

            WHEN B.CodTransaccion IN ('TAS','THA','TIS','TSA','STA','RBD','RAS','CSG','TIT')
              OR B.TextoRubroAnalitico LIKE '%TASA%'
              OR B.TextoRubroAnalitico LIKE '%SERVICIO%'
              OR B.TextoRubroAnalitico LIKE '%PERMISO%'
              OR B.TextoRubroAnalitico LIKE '%RECOLECCION%'
                THEN '04_TASAS_MUNICIPALES'

            WHEN B.CodTransaccion = 'CEM'
              OR B.TextoRubroAnalitico LIKE '%CONTRIBUCION%'
              OR B.TextoRubroAnalitico LIKE '%MEJORA%'
                THEN '05_CONTRIBUCIONES_ESPECIALES'

            WHEN B.TextoRubroAnalitico LIKE '%MULTA%'
              OR B.TextoRubroAnalitico LIKE '%SANCION%'
              OR B.TextoRubroAnalitico LIKE '%INFRACCION%'
                THEN '06_MULTAS_Y_SANCIONES'

            WHEN B.CodTransaccion IN ('CIP','PDP')
              OR B.TextoRubroAnalitico LIKE '%CONVENIO%'
              OR B.TextoRubroAnalitico LIKE '%ABONO%'
                THEN '07_CONVENIOS_Y_RECUPERACION'

            ELSE '99_OTROS_INGRESOS'
        END AS FamiliaIngreso

    FROM DetalleBase AS B
),

PreparadaActual AS
(
    SELECT
        C.*,

        CAST(
              ISNULL(C.TotalBanred,0)
            + ISNULL(C.TotalCheque,0)
            + ISNULL(C.TotalSPIConsolidado,0)
            + ISNULL(C.TotalTarjetaCredito,0)
            + ISNULL(C.TotalEfectivo,0)
            + ISNULL(C.TotalNotaCredito,0)
            AS DECIMAL(38,6)
        ) AS TotalMediosConsolidados

    FROM ClasificadaActual AS C
),

MediosActual AS
(
    SELECT
        P.*,
        MP.OrdenMedioPago,
        MP.MedioPago,

        CAST(
            CASE
                WHEN ABS(P.TotalMediosConsolidados) > 0.000001
                    THEN
                        CAST(P.ValorDetalleEMAS AS DECIMAL(38,12))
                        * CAST(MP.ValorMedioPagoCobro AS DECIMAL(38,12))
                        / CAST(P.TotalMediosConsolidados AS DECIMAL(38,12))
                ELSE 0
            END
            AS DECIMAL(38,12)
        ) AS ValorMedioPagoProporcional

    FROM PreparadaActual AS P

    CROSS APPLY
    (
        VALUES
            (1,'BANRED',          P.TotalBanred),
            (2,'CHEQUE',          P.TotalCheque),
            (3,'SPI',             P.TotalSPIConsolidado),
            (4,'TARJETA_CREDITO', P.TotalTarjetaCredito),
            (5,'EFECTIVO',        P.TotalEfectivo),
            (6,'NOTA_CREDITO',    P.TotalNotaCredito)
    ) AS MP(OrdenMedioPago,MedioPago,ValorMedioPagoCobro)

    WHERE ABS(MP.ValorMedioPagoCobro) > 0.000001
),

BalanceActual AS
(
    SELECT
        M.*,

        MAX(M.OrdenMedioPago)
            OVER(PARTITION BY M.IdFactDesgloseCobro) AS UltimoMedioDetalle,

        SUM(M.ValorMedioPagoProporcional)
            OVER(PARTITION BY M.IdFactDesgloseCobro) AS SumaProporcionalDetalle

    FROM MediosActual AS M
),

PagosActual AS
(
    SELECT
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,

        Transaccion,
        Tipo,
        ClaseIngreso,
        FamiliaIngreso,
        CodigoRubroCompleto,
        SubTransaccion,
        Detalle,

        OrdenMedioPago,
        MedioPago,
        CanalRecaudacion,

        CAST(
            CASE
                WHEN OrdenMedioPago = UltimoMedioDetalle
                    THEN ValorMedioPagoProporcional
                       + (
                            CAST(ValorDetalleEMAS AS DECIMAL(38,12))
                            - SumaProporcionalDetalle
                         )
                ELSE ValorMedioPagoProporcional
            END
            AS DECIMAL(38,12)
        ) AS ValorRecaudacion

    FROM BalanceActual
),

GerencialActual AS
(
    SELECT
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,
        Transaccion,
        Tipo,
        ClaseIngreso,
        FamiliaIngreso,
        CodigoRubroCompleto,
        SubTransaccion,
        Detalle,
        OrdenMedioPago,
        MedioPago,
        CanalRecaudacion,

        CAST(SUM(ValorRecaudacion) AS DECIMAL(38,6)) AS ValorRecaudacion

    FROM PagosActual

    WHERE ABS(ValorRecaudacion) > 0.000001

    GROUP BY
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,
        Transaccion,
        Tipo,
        ClaseIngreso,
        FamiliaIngreso,
        CodigoRubroCompleto,
        SubTransaccion,
        Detalle,
        OrdenMedioPago,
        MedioPago,
        CanalRecaudacion
),

/*==============================================================================
 2. PAGOS 2025
    Fuente agregada que sí contiene los 12 meses de 2025 y los seis medios.
    No se obliga a llegar al nivel cajero.
==============================================================================*/
Base2025 AS
(
    SELECT
        TRY_CONVERT(INT,F.AnioCobro) AS AnioCobro,
        MONTH(F.FechaCobro) AS MesCobroNumero,
        F.MesLetras AS MesCobroNombre,

        LTRIM(RTRIM(TD.CodTransaccion)) AS CodTransaccion,
        LTRIM(RTRIM(TD.Transaccion)) AS Transaccion,

        TD.CodSubTransaccion,
        LTRIM(RTRIM(TD.SubTransaccion)) AS SubTransaccion,

        TD.CodDetalle,
        LTRIM(RTRIM(TD.Detalle)) AS Detalle,

        LTRIM(RTRIM(TD.Tipo)) AS Tipo,

        CONCAT(
            LTRIM(RTRIM(TD.CodTransaccion)), '-',
            RIGHT('000' + CONVERT(VARCHAR(10),TD.CodSubTransaccion),3), '-',
            RIGHT('000' + CONVERT(VARCHAR(10),TD.CodDetalle),3)
        ) AS CodigoRubroCompleto,

        UPPER(CONCAT(
            ISNULL(TD.CodTransaccion,''), ' ',
            ISNULL(TD.Transaccion,''), ' ',
            ISNULL(TD.SubTransaccion,''), ' ',
            ISNULL(TD.Detalle,''), ' ',
            ISNULL(TD.Tipo,'')
        )) AS TextoRubroAnalitico,

        CAST(ISNULL(T.ValorBanRed,0) AS DECIMAL(38,6)) AS ValorBanred,
        CAST(ISNULL(T.ValorCheque,0) AS DECIMAL(38,6)) AS ValorCheque,
        CAST(ISNULL(T.ValorSpi,0) AS DECIMAL(38,6)) AS ValorSPI,
        CAST(ISNULL(T.ValorTarjetaCredito,0) AS DECIMAL(38,6)) AS ValorTarjeta,
        CAST(ISNULL(T.ValorEfectivo,0) AS DECIMAL(38,6)) AS ValorEfectivo,
        CAST(ISNULL(T.ValorNotaCredito,0) AS DECIMAL(38,6)) AS ValorNotaCredito

    FROM RECAUDACION_DM.RecaudacionNeta.FactDesgloseCobroTransaccion AS T

    INNER JOIN RECAUDACION_DM.RecaudacionNeta.DimFechaCobro AS F
        ON T.IdDimFechaCobro = F.IdDimFechaCobro

    INNER JOIN RECAUDACION_DM.RecaudacionNeta.DimTransaccionDesglose AS TD
        ON T.IdDimTransaccionDesglose = TD.IdDimTransaccionDesglose

    WHERE F.FechaCobro >= '2025-01-01'
      AND F.FechaCobro <  '2026-01-01'
),

Clasificada2025 AS
(
    SELECT
        B.*,

        CASE
            WHEN B.Tipo LIKE '02%Fondos%'
                THEN 'FONDO_TERCERO_CONFIRMADO'
            WHEN B.TextoRubroAnalitico LIKE '%JUNTA DE BENEFICENCIA%'
              OR B.TextoRubroAnalitico LIKE '%BOMBERO%'
              OR B.TextoRubroAnalitico LIKE '%BOMBEROS%'
              OR B.TextoRubroAnalitico LIKE '%CONSEJO PROVINCIAL%'
              OR B.TextoRubroAnalitico LIKE '%ECAPAG%'
              OR B.TextoRubroAnalitico LIKE '%FONDO%TERCERO%'
                THEN 'POSIBLE_FONDO_TERCERO_REVISAR'
            ELSE 'INGRESO_PROPIO_O_MUNICIPAL'
        END AS ClaseIngreso,

        CASE
            WHEN B.Tipo LIKE '02%Fondos%'
                THEN '08_FONDOS_DE_TERCEROS'
            WHEN B.CodTransaccion IN ('PDR','PRU')
              OR B.TextoRubroAnalitico LIKE '%PREDIAL%'
              OR B.TextoRubroAnalitico LIKE '%PREDIO%'
                THEN '01_IMPUESTOS_PREDIALES'
            WHEN B.CodTransaccion IN ('PAT','MIL')
              OR B.TextoRubroAnalitico LIKE '%PATENTE%'
              OR B.TextoRubroAnalitico LIKE '%1.5%'
              OR B.TextoRubroAnalitico LIKE '%ACTIVOS TOTALES%'
                THEN '02_IMPUESTOS_ACTIVIDAD_ECONOMICA'
            WHEN B.CodTransaccion IN ('ALC','PLS','IRV','IVE')
              OR B.TextoRubroAnalitico LIKE '%ALCABALA%'
              OR B.TextoRubroAnalitico LIKE '%PLUSVAL%'
              OR B.TextoRubroAnalitico LIKE '%TRANSFERENCIA DE DOMINIO%'
                THEN '03_IMPUESTOS_TRANSFERENCIA_DOMINIO'
            WHEN B.CodTransaccion IN ('TAS','THA','TIS','TSA','STA','RBD','RAS','CSG','TIT')
              OR B.TextoRubroAnalitico LIKE '%TASA%'
              OR B.TextoRubroAnalitico LIKE '%SERVICIO%'
              OR B.TextoRubroAnalitico LIKE '%PERMISO%'
              OR B.TextoRubroAnalitico LIKE '%RECOLECCION%'
                THEN '04_TASAS_MUNICIPALES'
            WHEN B.CodTransaccion = 'CEM'
              OR B.TextoRubroAnalitico LIKE '%CONTRIBUCION%'
              OR B.TextoRubroAnalitico LIKE '%MEJORA%'
                THEN '05_CONTRIBUCIONES_ESPECIALES'
            WHEN B.TextoRubroAnalitico LIKE '%MULTA%'
              OR B.TextoRubroAnalitico LIKE '%SANCION%'
              OR B.TextoRubroAnalitico LIKE '%INFRACCION%'
                THEN '06_MULTAS_Y_SANCIONES'
            WHEN B.CodTransaccion IN ('CIP','PDP')
              OR B.TextoRubroAnalitico LIKE '%CONVENIO%'
              OR B.TextoRubroAnalitico LIKE '%ABONO%'
                THEN '07_CONVENIOS_Y_RECUPERACION'
            ELSE '99_OTROS_INGRESOS'
        END AS FamiliaIngreso

    FROM Base2025 AS B
),

Pagos2025 AS
(
    SELECT
        C.AnioCobro,
        C.MesCobroNumero,
        C.MesCobroNombre,
        C.Transaccion,
        C.Tipo,
        C.ClaseIngreso,
        C.FamiliaIngreso,
        C.CodigoRubroCompleto,
        C.SubTransaccion,
        C.Detalle,

        MP.OrdenMedioPago,
        MP.MedioPago,
        CAST('NO_DISPONIBLE_2025' AS VARCHAR(50)) AS CanalRecaudacion,

        CAST(MP.Valor AS DECIMAL(38,6)) AS ValorRecaudacion

    FROM Clasificada2025 AS C

    CROSS APPLY
    (
        VALUES
            (1,'BANRED',          C.ValorBanred),
            (2,'CHEQUE',          C.ValorCheque),
            (3,'SPI',             C.ValorSPI),
            (4,'TARJETA_CREDITO', C.ValorTarjeta),
            (5,'EFECTIVO',        C.ValorEfectivo),
            (6,'NOTA_CREDITO',    C.ValorNotaCredito)
    ) AS MP(OrdenMedioPago,MedioPago,Valor)

    WHERE ABS(MP.Valor) > 0.000001
),

Gerencial2025 AS
(
    SELECT
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,
        Transaccion,
        Tipo,
        ClaseIngreso,
        FamiliaIngreso,
        CodigoRubroCompleto,
        SubTransaccion,
        Detalle,
        OrdenMedioPago,
        MedioPago,
        CanalRecaudacion,

        CAST(SUM(ValorRecaudacion) AS DECIMAL(38,6)) AS ValorRecaudacion

    FROM Pagos2025

    GROUP BY
        AnioCobro,
        MesCobroNumero,
        MesCobroNombre,
        Transaccion,
        Tipo,
        ClaseIngreso,
        FamiliaIngreso,
        CodigoRubroCompleto,
        SubTransaccion,
        Detalle,
        OrdenMedioPago,
        MedioPago,
        CanalRecaudacion
)

/*==============================================================================
 RESULTADO FINAL
==============================================================================*/
SELECT
    AnioCobro,
    MesCobroNumero,
    MesCobroNombre,
    Transaccion,
    Tipo,
    ClaseIngreso,
    FamiliaIngreso,
    CodigoRubroCompleto,
    SubTransaccion,
    Detalle,
    OrdenMedioPago,
    MedioPago,
    CanalRecaudacion,
    ValorRecaudacion
FROM GerencialActual

UNION ALL

SELECT
    AnioCobro,
    MesCobroNumero,
    MesCobroNombre,
    Transaccion,
    Tipo,
    ClaseIngreso,
    FamiliaIngreso,
    CodigoRubroCompleto,
    SubTransaccion,
    Detalle,
    OrdenMedioPago,
    MedioPago,
    CanalRecaudacion,
    ValorRecaudacion
FROM Gerencial2025;
