/*
 * ============================================================================
 * CONSULTA: recaudacion auditoria por cajero
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Recaudación Municipal: Tablero Ejecutivo
 * Página / destino    : DESGLOSE POR CAJERO
 * Qué responde        : Detalle de auditoría por cajero desde el 1 de enero de 2026: llaves de auditoría, usuario técnico, nombre visible y marca de posible duplicado entre SPI y transferencia, para cuadrar asignaciones.
 * Bases de origen     : RECAUDACION_DM: DesgloseCobros (FactCobro, FactCobrosConTransaferenciaSpi y dimensiones)
 * Granularidad        : Cobro por medio de pago y cajero
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Los comentarios que mencionaban a una persona real se reemplazaron por marcadores.
 * ============================================================================
 */

/*==============================================================================
 FACT_RECAUDACION_AUDITORIA_V5_CUADRE_EMAS

 Conserva:
 - llaves necesarias de auditoría
 - usuario técnico fuente
 - nombre visible obtenido desde la misma base
 - valores necesarios para revisar asignaciones y SPI

 Elimina columnas descriptivas duplicadas.
 ValorRecaudacion conserva 6 decimales para evitar acumulación de redondeos.
==============================================================================*/

WITH Parametros AS
(
    SELECT
        CAST('2026-01-01' AS DATE) AS FechaDesde,
        CAST(GETDATE() AS DATE) AS FechaHasta
),

SPI AS
(
    SELECT
        S.IdFactCobro,
        CAST(SUM(ISNULL(S.Valor,0)) AS DECIMAL(38,6)) AS ValorSPI
    FROM RECAUDACION_DM.DesgloseCobros.FactCobrosConTransaferenciaSpi AS S
    GROUP BY S.IdFactCobro
),

DetalleBase AS
(
    SELECT
        C.IdFactCobro,
        D.IdFactDesgloseCobro,

        /* Fecha: solo lo necesario para Power BI */
        FC.FechaCobro,
        TRY_CONVERT(INT, FC.AnioCobro) AS AnioCobro,
        MONTH(FC.FechaCobro) AS MesCobroNumero,
        FC.MesLetras AS MesCobroNombre,

        /* Rubro */
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

        /* Usuario técnico registrado por la misma base */
        ISNULL(
            NULLIF(LTRIM(RTRIM(D.UsuarioAuditoria)),''),
            'SIN_USUARIO'
        ) AS UsuarioCajeroFuente,

        /* Canal y nombre/entidad registrados por la base */
        ISNULL(
            NULLIF(LTRIM(RTRIM(CP.CanalDePago)),''),
            'SIN_CANAL'
        ) AS CanalRecaudacion,

        ISNULL(
            NULLIF(LTRIM(RTRIM(B.Banco)),''),
            'SIN_ENTIDAD'
        ) AS BancoEntidadFuente,

        CAST(ISNULL(D.Valor,0) AS DECIMAL(38,6)) AS ValorDetalleEMAS,

        /* Medios válidos */
        CAST(ISNULL(C.TotalExterno,0) AS DECIMAL(38,6)) AS TotalBanred,
        CAST(ISNULL(C.TotalCheque,0) AS DECIMAL(38,6)) AS TotalCheque,
        CAST(ISNULL(C.TotalTarjeta,0) AS DECIMAL(38,6)) AS TotalTarjetaCredito,
        CAST(ISNULL(C.TotalEfectivo,0) AS DECIMAL(38,6)) AS TotalEfectivo,
        CAST(ISNULL(C.TotalNotaCredito,0) AS DECIMAL(38,6)) AS TotalNotaCredito,

        /*
          SPI consolidado.
          TotalTransferencia no se genera como fila adicional.
        */
        CAST(
            CASE
                WHEN ABS(ISNULL(S.ValorSPI,0)) > 0.000001
                    THEN ISNULL(S.ValorSPI,0)
                ELSE ISNULL(C.TotalTransferencia,0)
            END
            AS DECIMAL(38,6)
        ) AS TotalSPIConsolidado,

        /* Solo para auditoría del problema SPI/Transferencia */
        CAST(ISNULL(S.ValorSPI,0) AS DECIMAL(38,6)) AS ValorSPIFuente,
        CAST(ISNULL(C.TotalTransferencia,0) AS DECIMAL(38,6)) AS ValorTransferenciaFuente,

        CASE
            WHEN ABS(ISNULL(S.ValorSPI,0)) > 0.000001
             AND ABS(ISNULL(C.TotalTransferencia,0)) > 0.000001
             AND ABS(ISNULL(S.ValorSPI,0)-ISNULL(C.TotalTransferencia,0)) <= 0.01
                THEN 1
            ELSE 0
        END AS FlagSPITransferenciaDuplicados

    FROM RECAUDACION_DM.DesgloseCobros.FactCobro AS C

    INNER JOIN RECAUDACION_DM.DesgloseCobros.FactDesgloseCobro AS D
        ON D.IdFactCobro = C.IdFactCobro

    INNER JOIN RECAUDACION_DM.DesgloseCobros.DimFechaCobro AS FC
        ON C.IdDimFechaCobro = FC.IdDimFechaCobro

    INNER JOIN RECAUDACION_DM.DesgloseCobros.DimTransaccionDesglose AS TD
        ON D.IdDimTransaccionDesglose = TD.IdDimTransaccionDesglose

    LEFT JOIN RECAUDACION_DM.DesgloseCobros.DimCanalDePago AS CP
        ON C.IdDimCanalDePago = CP.IdDimCanalDePago

    LEFT JOIN RECAUDACION_DM.DesgloseCobros.DimBanco AS B
        ON C.IdDimBanco = B.IdDimBanco

    LEFT JOIN SPI AS S
        ON S.IdFactCobro = C.IdFactCobro

    CROSS JOIN Parametros AS P

    WHERE UPPER(LTRIM(RTRIM(C.Estado))) = 'PAGO'
      AND FC.FechaCobro >= P.FechaDesde
      AND FC.FechaCobro < DATEADD(DAY,1,P.FechaHasta)
),

Clasificada AS
(
    SELECT
        DB.*,

        CASE
            WHEN DB.Tipo LIKE '02%Fondos%'
                THEN 'FONDO_TERCERO_CONFIRMADO'

            WHEN DB.TextoRubroAnalitico LIKE '%JUNTA DE BENEFICENCIA%'
              OR DB.TextoRubroAnalitico LIKE '%BOMBERO%'
              OR DB.TextoRubroAnalitico LIKE '%BOMBEROS%'
              OR DB.TextoRubroAnalitico LIKE '%CONSEJO PROVINCIAL%'
              OR DB.TextoRubroAnalitico LIKE '%ECAPAG%'
              OR DB.TextoRubroAnalitico LIKE '%FONDO%TERCERO%'
                THEN 'POSIBLE_FONDO_TERCERO_REVISAR'

            ELSE 'INGRESO_PROPIO_O_MUNICIPAL'
        END AS ClaseIngreso,

        CASE
            WHEN DB.Tipo LIKE '02%Fondos%'
                THEN '08_FONDOS_DE_TERCEROS'

            WHEN DB.CodTransaccion IN ('PDR','PRU')
              OR DB.TextoRubroAnalitico LIKE '%PREDIAL%'
              OR DB.TextoRubroAnalitico LIKE '%PREDIO%'
                THEN '01_IMPUESTOS_PREDIALES'

            WHEN DB.CodTransaccion IN ('PAT','MIL')
              OR DB.TextoRubroAnalitico LIKE '%PATENTE%'
              OR DB.TextoRubroAnalitico LIKE '%1.5%'
              OR DB.TextoRubroAnalitico LIKE '%ACTIVOS TOTALES%'
                THEN '02_IMPUESTOS_ACTIVIDAD_ECONOMICA'

            WHEN DB.CodTransaccion IN ('ALC','PLS','IRV','IVE')
              OR DB.TextoRubroAnalitico LIKE '%ALCABALA%'
              OR DB.TextoRubroAnalitico LIKE '%PLUSVAL%'
              OR DB.TextoRubroAnalitico LIKE '%TRANSFERENCIA DE DOMINIO%'
                THEN '03_IMPUESTOS_TRANSFERENCIA_DOMINIO'

            WHEN DB.CodTransaccion IN ('TAS','THA','TIS','TSA','STA','RBD','RAS','CSG','TIT')
              OR DB.TextoRubroAnalitico LIKE '%TASA%'
              OR DB.TextoRubroAnalitico LIKE '%SERVICIO%'
              OR DB.TextoRubroAnalitico LIKE '%PERMISO%'
              OR DB.TextoRubroAnalitico LIKE '%RECOLECCION%'
                THEN '04_TASAS_MUNICIPALES'

            WHEN DB.CodTransaccion = 'CEM'
              OR DB.TextoRubroAnalitico LIKE '%CONTRIBUCION%'
              OR DB.TextoRubroAnalitico LIKE '%MEJORA%'
                THEN '05_CONTRIBUCIONES_ESPECIALES'

            WHEN DB.TextoRubroAnalitico LIKE '%MULTA%'
              OR DB.TextoRubroAnalitico LIKE '%SANCION%'
              OR DB.TextoRubroAnalitico LIKE '%INFRACCION%'
                THEN '06_MULTAS_Y_SANCIONES'

            WHEN DB.CodTransaccion IN ('CIP','PDP')
              OR DB.TextoRubroAnalitico LIKE '%CONVENIO%'
              OR DB.TextoRubroAnalitico LIKE '%ABONO%'
                THEN '07_CONVENIOS_Y_RECUPERACION'

            ELSE '99_OTROS_INGRESOS'
        END AS FamiliaIngreso

    FROM DetalleBase AS DB
),

Preparada AS
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
        ) AS TotalMediosConsolidados,

        (
            CASE WHEN ABS(ISNULL(C.TotalBanred,0))         > 0.000001 THEN 1 ELSE 0 END +
            CASE WHEN ABS(ISNULL(C.TotalCheque,0))         > 0.000001 THEN 1 ELSE 0 END +
            CASE WHEN ABS(ISNULL(C.TotalSPIConsolidado,0)) > 0.000001 THEN 1 ELSE 0 END +
            CASE WHEN ABS(ISNULL(C.TotalTarjetaCredito,0)) > 0.000001 THEN 1 ELSE 0 END +
            CASE WHEN ABS(ISNULL(C.TotalEfectivo,0))       > 0.000001 THEN 1 ELSE 0 END +
            CASE WHEN ABS(ISNULL(C.TotalNotaCredito,0))    > 0.000001 THEN 1 ELSE 0 END
        ) AS CantidadMediosPago

    FROM Clasificada AS C
),

MediosProporcionales AS
(
    SELECT
        P.*,
        MP.OrdenMedioPago,
        MP.MedioPago,

        /*
          Alta precision: no redondear a centavos en esta etapa.
        */
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
        ) AS ValorMedioPagoProporcional,

        CASE
            WHEN P.CantidadMediosPago <= 1
                THEN 'EXACTO_UN_SOLO_MEDIO'
            ELSE 'PROPORCIONAL_MULTIMEDIO'
        END AS TipoAsignacionMedioPago

    FROM Preparada AS P

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

MediosCalculados AS
(
    SELECT
        MP.*,

        MAX(MP.OrdenMedioPago)
            OVER (PARTITION BY MP.IdFactDesgloseCobro) AS UltimoMedioDetalle,

        SUM(MP.ValorMedioPagoProporcional)
            OVER (PARTITION BY MP.IdFactDesgloseCobro) AS SumaProporcionalDetalle

    FROM MediosProporcionales AS MP
),

Medios AS
(
    SELECT
        MC.*,

        /*
          BALANCE DE RESIDUO:
          El ultimo medio del detalle absorbe cualquier residuo decimal.
          Por construccion:
              SUM(ValorMedioPagoAsignado)
              por IdFactDesgloseCobro
              = ValorDetalleEMAS
          Esto evita diferencias acumuladas contra EMAS.
        */
        CAST(
            CASE
                WHEN MC.OrdenMedioPago = MC.UltimoMedioDetalle
                    THEN
                        MC.ValorMedioPagoProporcional
                        + (
                            CAST(MC.ValorDetalleEMAS AS DECIMAL(38,12))
                            - MC.SumaProporcionalDetalle
                          )
                ELSE MC.ValorMedioPagoProporcional
            END
            AS DECIMAL(38,12)
        ) AS ValorMedioPagoAsignado

    FROM MediosCalculados AS MC
),

FuenteFinal AS
(
    SELECT
        M.*,

        /*
          NOMBRE VISIBLE 100% DESDE LA BASE:
          En la muestra real, DimBanco.Banco contiene:
          <NOMBRE COMPLETO>
          mientras UsuarioAuditoria contiene <USUARIO>.

          Se prioriza BancoEntidadFuente cuando existe.
        */
        CASE
            WHEN M.BancoEntidadFuente <> 'SIN_ENTIDAD'
                THEN M.BancoEntidadFuente

            WHEN M.MedioPago = 'BANRED'
             AND M.CanalRecaudacion <> 'SIN_CANAL'
                THEN M.CanalRecaudacion

            ELSE M.UsuarioCajeroFuente
        END AS CajeroMedioFuente

    FROM Medios AS M
)


SELECT
    /* Trazabilidad */
    IdFactCobro,
    IdFactDesgloseCobro,

    /* Fecha */
    FechaCobro,
    AnioCobro,
    MesCobroNumero,
    MesCobroNombre,

    /* Jerarquía sin duplicar códigos */
    Transaccion,
    Tipo,
    ClaseIngreso,
    FamiliaIngreso,
    CodigoRubroCompleto,
    SubTransaccion,
    Detalle,

    /* Recaudación */
    OrdenMedioPago,
    MedioPago,
    CanalRecaudacion,

    /* Nombre legible 100% fuente */
    CajeroMedioFuente,

    /* Usuario técnico para rastreo */
    UsuarioCajeroFuente,

    TipoAsignacionMedioPago,

    /* Valores */
    CAST(ValorMedioPagoAsignado AS DECIMAL(38,6)) AS ValorRecaudacion,
    CAST(ValorDetalleEMAS AS DECIMAL(38,2)) AS ValorDetalleEMAS,

    /* Solo diagnóstico SPI / transferencia */
    CAST(ValorSPIFuente AS DECIMAL(38,2)) AS ValorSPIFuente,
    CAST(ValorTransferenciaFuente AS DECIMAL(38,2)) AS ValorTransferenciaFuente,
    FlagSPITransferenciaDuplicados

FROM FuenteFinal
WHERE ABS(ValorMedioPagoAsignado) > 0.000001;
 
