/*
 * ============================================================================
 * CONSULTA: ttv eventos de caja tickets sin pago y abonados
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Terminal de Transferencia de Víveres: Control de Tickets y Recaudación
 * Página / destino    : DASHBOARD, RESUMEN y TICKETS NO PAGADOS
 * Qué responde        : Consulta integral del terminal para 2026: eventos de caja (pago normal, repago y pago manual), tickets sin pago y movimientos de abonados y tarjetas, con indicadores de alerta.
 * Bases de origen     : TTV_DM: FactTicket, FactTarjetaAbonado
 * Granularidad        : Un registro por evento de caja, ticket sin pago o movimiento de abonado
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

/* ============================================================
   QUERY INTEGRAL POWER BI - TTV_DM
   Incluye:
   1. Eventos de caja: pago normal, repago, pago manual
   2. Tickets sin pago
   3. Movimientos de abonados / tarjetas

   Base:
   - TTV_DM.dbo.FactTicket
   - TTV_DM.dbo.FactTarjetaAbonado
   ============================================================ */

DECLARE @FechaInicio DATETIME = '2026-01-01';
DECLARE @FechaFinExclusiva DATETIME = DATEADD(DAY, 1, CAST('2026-12-31' AS DATETIME));

WITH BaseEventosTTV AS (

    /* ============================================================
       1. PAGO NORMAL
       ============================================================ */
    SELECT
        'TICKET' AS FuenteTTV,
        'EVENTO DE CAJA' AS TipoRegistro,
        'PAGO NORMAL' AS TipoMovimiento,

        CONCAT('TICKET-', CAST(f.TICKET_NUMERO AS VARCHAR(100)), '-PAGO') AS IdOperacionTTV,

        CAST(f.TICKET_NUMERO AS VARCHAR(100)) AS TICKET_NUMERO,
        f.TICKET_FECHA_HORA_EMISION,
        CAST(f.TICKET_TIPO_VEHICULO AS VARCHAR(100)) AS TICKET_TIPO_VEHICULO,
        CAST(f.TICKET_PLACA AS VARCHAR(100)) AS TICKET_PLACA,
        ISNULL(NULLIF(TRY_CONVERT(INT, f.TICKET_CANTIDADTICKETS), 0), 1) AS TICKET_CANTIDADTICKETS,

        f.CREACION_FECHA,
        CAST(f.CREACION_EQUIPO AS VARCHAR(100)) AS CREACION_EQUIPO,
        CAST(f.CREACION_ZONA AS VARCHAR(100)) AS CREACION_ZONA,

        f.ENTRADA_FECHA,
        CAST(f.ENTRADA_EQUIPO AS VARCHAR(100)) AS ENTRADA_EQUIPO,
        CAST(f.ENTRADA_ZONA AS VARCHAR(100)) AS ENTRADA_ZONA,

        f.SALIDA_FECHA,
        CAST(f.SALIDA_EQUIPO AS VARCHAR(100)) AS SALIDA_EQUIPO,
        CAST(f.SALIDA_ZONA AS VARCHAR(100)) AS SALIDA_ZONA,

        f.DESTRUCCION_FECHA,
        CAST(f.DESTRUCCION_EQUIPO AS VARCHAR(100)) AS DESTRUCCION_EQUIPO,
        CAST(f.DESTRUCCION_ZONA AS VARCHAR(100)) AS DESTRUCCION_ZONA,

        CAST(f.ANULACION_TIENE_ANULACION AS VARCHAR(30)) AS ANULACION_TIENE_ANULACION,
        f.ANULACION_FECHA_ANULACION,
        CAST(f.ANULACION_TIPO_ANULACION AS VARCHAR(200)) AS ANULACION_TIPO_ANULACION,

        COALESCE(f.PAGO_FECHA_COBRO, f.PAGO_FECHA) AS FechaAnalisis,
        COALESCE(f.PAGO_FECHA_COBRO, f.PAGO_FECHA) AS FechaPagoReal,
        f.PAGO_FECHA AS FechaOperacion,
        f.PAGO_FECHA_COBRO AS FechaCobroSistema,

        CAST(f.PAGO_EQUIPO AS VARCHAR(100)) AS CodigoCaja,
        CAST(f.PAGO_NOMBRE_EQUIPO AS VARCHAR(200)) AS CajaRecaudadoraOriginal,
        CAST(f.PAGO_ZONA AS VARCHAR(100)) AS ZonaCaja,

        CAST(f.PAGO_CODIGO_SISTEMA AS VARCHAR(100)) AS CodigoSistema,
        CAST(f.PAGO_OID_EQUIPO AS VARCHAR(100)) AS OidEquipo,
        CAST(f.PAGO_CODIGO_PERIODO_LOCAL AS VARCHAR(100)) AS CodigoPeriodoLocal,
        CAST(f.PAGO_CODIGO_COBRO AS VARCHAR(100)) AS CodigoCobro,

        ISNULL(NULLIF(TRY_CONVERT(INT, f.PAGO_CANTIDADTICKETS), 0), 1) AS CantidadTicketsPagados,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.PAGO_IMPORTE), 0) AS ValorPagado,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.PAGO_IMPORTE_OPERACION), 0) AS ValorOperacion,

        CAST(NULL AS VARCHAR(100)) AS IdFactTarjetaAbonado,
        CAST(NULL AS VARCHAR(200)) AS ProductoAbonoContratado,
        CAST(NULL AS VARCHAR(300)) AS Cliente,
        CAST(NULL AS VARCHAR(100)) AS Tarjeta,
        CAST(NULL AS VARCHAR(100)) AS Matricula,
        CAST(NULL AS VARCHAR(100)) AS TiempoEstanciaAbonadoTexto,
        CAST(NULL AS DECIMAL(18,2)) AS TiempoEstanciaAbonadoNumero,
        CAST(NULL AS VARCHAR(100)) AS IdEquipoAbonado,
        CAST(NULL AS VARCHAR(100)) AS IdDimHorario

    FROM [TTV_DM].[dbo].[FactTicket] f
    WHERE
        UPPER(LTRIM(RTRIM(ISNULL(CAST(f.PAGO_TIENEPAGO AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
        AND (
                f.PAGO_FECHA_COBRO >= @FechaInicio
            AND f.PAGO_FECHA_COBRO <  @FechaFinExclusiva
            OR (
                    f.PAGO_FECHA_COBRO IS NULL
                AND f.PAGO_FECHA >= @FechaInicio
                AND f.PAGO_FECHA <  @FechaFinExclusiva
               )
        )

    UNION ALL

    /* ============================================================
       2. REPAGO
       ============================================================ */
    SELECT
        'TICKET' AS FuenteTTV,
        'EVENTO DE CAJA' AS TipoRegistro,
        'REPAGO' AS TipoMovimiento,

        CONCAT('TICKET-', CAST(f.TICKET_NUMERO AS VARCHAR(100)), '-REPAGO') AS IdOperacionTTV,

        CAST(f.TICKET_NUMERO AS VARCHAR(100)) AS TICKET_NUMERO,
        f.TICKET_FECHA_HORA_EMISION,
        CAST(f.TICKET_TIPO_VEHICULO AS VARCHAR(100)) AS TICKET_TIPO_VEHICULO,
        CAST(f.TICKET_PLACA AS VARCHAR(100)) AS TICKET_PLACA,
        ISNULL(NULLIF(TRY_CONVERT(INT, f.TICKET_CANTIDADTICKETS), 0), 1) AS TICKET_CANTIDADTICKETS,

        f.CREACION_FECHA,
        CAST(f.CREACION_EQUIPO AS VARCHAR(100)) AS CREACION_EQUIPO,
        CAST(f.CREACION_ZONA AS VARCHAR(100)) AS CREACION_ZONA,

        f.ENTRADA_FECHA,
        CAST(f.ENTRADA_EQUIPO AS VARCHAR(100)) AS ENTRADA_EQUIPO,
        CAST(f.ENTRADA_ZONA AS VARCHAR(100)) AS ENTRADA_ZONA,

        f.SALIDA_FECHA,
        CAST(f.SALIDA_EQUIPO AS VARCHAR(100)) AS SALIDA_EQUIPO,
        CAST(f.SALIDA_ZONA AS VARCHAR(100)) AS SALIDA_ZONA,

        f.DESTRUCCION_FECHA,
        CAST(f.DESTRUCCION_EQUIPO AS VARCHAR(100)) AS DESTRUCCION_EQUIPO,
        CAST(f.DESTRUCCION_ZONA AS VARCHAR(100)) AS DESTRUCCION_ZONA,

        CAST(f.ANULACION_TIENE_ANULACION AS VARCHAR(30)) AS ANULACION_TIENE_ANULACION,
        f.ANULACION_FECHA_ANULACION,
        CAST(f.ANULACION_TIPO_ANULACION AS VARCHAR(200)) AS ANULACION_TIPO_ANULACION,

        COALESCE(f.REPAGO_FECHA_COBRO, f.REPAGO_FECHA) AS FechaAnalisis,
        COALESCE(f.REPAGO_FECHA_COBRO, f.REPAGO_FECHA) AS FechaPagoReal,
        f.REPAGO_FECHA AS FechaOperacion,
        f.REPAGO_FECHA_COBRO AS FechaCobroSistema,

        CAST(f.REPAGO_EQUIPO AS VARCHAR(100)) AS CodigoCaja,
        CAST(f.REPAGO_NOMBRE_EQUIPO AS VARCHAR(200)) AS CajaRecaudadoraOriginal,
        CAST(f.REPAGO_ZONA AS VARCHAR(100)) AS ZonaCaja,

        CAST(f.REPAGO_CODIGO_SISTEMA AS VARCHAR(100)) AS CodigoSistema,
        CAST(f.REPAGO_OID_EQUIPO AS VARCHAR(100)) AS OidEquipo,
        CAST(f.REPAGO_CODIGO_PERIODO_LOCAL AS VARCHAR(100)) AS CodigoPeriodoLocal,
        CAST(f.REPAGO_CODIGO_COBRO AS VARCHAR(100)) AS CodigoCobro,

        ISNULL(NULLIF(TRY_CONVERT(INT, f.REPAGO_CANTIDADTICKETS), 0), 1) AS CantidadTicketsPagados,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.REPAGO_IMPORTE), 0) AS ValorPagado,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.REPAGO_IMPORTE_OPERACION), 0) AS ValorOperacion,

        CAST(NULL AS VARCHAR(100)) AS IdFactTarjetaAbonado,
        CAST(NULL AS VARCHAR(200)) AS ProductoAbonoContratado,
        CAST(NULL AS VARCHAR(300)) AS Cliente,
        CAST(NULL AS VARCHAR(100)) AS Tarjeta,
        CAST(NULL AS VARCHAR(100)) AS Matricula,
        CAST(NULL AS VARCHAR(100)) AS TiempoEstanciaAbonadoTexto,
        CAST(NULL AS DECIMAL(18,2)) AS TiempoEstanciaAbonadoNumero,
        CAST(NULL AS VARCHAR(100)) AS IdEquipoAbonado,
        CAST(NULL AS VARCHAR(100)) AS IdDimHorario

    FROM [TTV_DM].[dbo].[FactTicket] f
    WHERE
        UPPER(LTRIM(RTRIM(ISNULL(CAST(f.REPAGO_TIENEREPAGO AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
        AND (
                f.REPAGO_FECHA_COBRO >= @FechaInicio
            AND f.REPAGO_FECHA_COBRO <  @FechaFinExclusiva
            OR (
                    f.REPAGO_FECHA_COBRO IS NULL
                AND f.REPAGO_FECHA >= @FechaInicio
                AND f.REPAGO_FECHA <  @FechaFinExclusiva
               )
        )

    UNION ALL

    /* ============================================================
       3. PAGO MANUAL
       ============================================================ */
    SELECT
        'TICKET' AS FuenteTTV,
        'EVENTO DE CAJA' AS TipoRegistro,
        'PAGO MANUAL' AS TipoMovimiento,

        CONCAT('TICKET-', CAST(f.TICKET_NUMERO AS VARCHAR(100)), '-PAGO-MANUAL') AS IdOperacionTTV,

        CAST(f.TICKET_NUMERO AS VARCHAR(100)) AS TICKET_NUMERO,
        f.TICKET_FECHA_HORA_EMISION,
        CAST(f.TICKET_TIPO_VEHICULO AS VARCHAR(100)) AS TICKET_TIPO_VEHICULO,
        CAST(f.TICKET_PLACA AS VARCHAR(100)) AS TICKET_PLACA,
        ISNULL(NULLIF(TRY_CONVERT(INT, f.TICKET_CANTIDADTICKETS), 0), 1) AS TICKET_CANTIDADTICKETS,

        f.CREACION_FECHA,
        CAST(f.CREACION_EQUIPO AS VARCHAR(100)) AS CREACION_EQUIPO,
        CAST(f.CREACION_ZONA AS VARCHAR(100)) AS CREACION_ZONA,

        f.ENTRADA_FECHA,
        CAST(f.ENTRADA_EQUIPO AS VARCHAR(100)) AS ENTRADA_EQUIPO,
        CAST(f.ENTRADA_ZONA AS VARCHAR(100)) AS ENTRADA_ZONA,

        f.SALIDA_FECHA,
        CAST(f.SALIDA_EQUIPO AS VARCHAR(100)) AS SALIDA_EQUIPO,
        CAST(f.SALIDA_ZONA AS VARCHAR(100)) AS SALIDA_ZONA,

        f.DESTRUCCION_FECHA,
        CAST(f.DESTRUCCION_EQUIPO AS VARCHAR(100)) AS DESTRUCCION_EQUIPO,
        CAST(f.DESTRUCCION_ZONA AS VARCHAR(100)) AS DESTRUCCION_ZONA,

        CAST(f.ANULACION_TIENE_ANULACION AS VARCHAR(30)) AS ANULACION_TIENE_ANULACION,
        f.ANULACION_FECHA_ANULACION,
        CAST(f.ANULACION_TIPO_ANULACION AS VARCHAR(200)) AS ANULACION_TIPO_ANULACION,

        COALESCE(f.PAGOMANUAL_FECHA_COBRO, f.PAGOMANUAL_FECHA) AS FechaAnalisis,
        COALESCE(f.PAGOMANUAL_FECHA_COBRO, f.PAGOMANUAL_FECHA) AS FechaPagoReal,
        f.PAGOMANUAL_FECHA AS FechaOperacion,
        f.PAGOMANUAL_FECHA_COBRO AS FechaCobroSistema,

        CAST(f.PAGOMANUAL_EQUIPO AS VARCHAR(100)) AS CodigoCaja,
        CAST(f.PAGOMANUAL_NOMBRE_EQUIPO AS VARCHAR(200)) AS CajaRecaudadoraOriginal,
        CAST(f.PAGOMANUAL_ZONA AS VARCHAR(100)) AS ZonaCaja,

        CAST(f.PAGOMANUAL_CODIGO_SISTEMA AS VARCHAR(100)) AS CodigoSistema,
        CAST(f.PAGOMANUAL_OID_EQUIPO AS VARCHAR(100)) AS OidEquipo,
        CAST(f.PAGOMANUAL_CODIGO_PERIODO_LOCAL AS VARCHAR(100)) AS CodigoPeriodoLocal,
        CAST(f.PAGOMANUAL_CODIGO_COBRO AS VARCHAR(100)) AS CodigoCobro,

        ISNULL(NULLIF(TRY_CONVERT(INT, f.PAGOMANUAL_CANTIDADTICKETS), 0), 1) AS CantidadTicketsPagados,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.PAGOMANUAL_IMPORTE), 0) AS ValorPagado,
        ISNULL(TRY_CONVERT(DECIMAL(18,2), f.PAGOMANUAL_IMPORTE_OPERACION), 0) AS ValorOperacion,

        CAST(NULL AS VARCHAR(100)) AS IdFactTarjetaAbonado,
        CAST(NULL AS VARCHAR(200)) AS ProductoAbonoContratado,
        CAST(NULL AS VARCHAR(300)) AS Cliente,
        CAST(NULL AS VARCHAR(100)) AS Tarjeta,
        CAST(NULL AS VARCHAR(100)) AS Matricula,
        CAST(NULL AS VARCHAR(100)) AS TiempoEstanciaAbonadoTexto,
        CAST(NULL AS DECIMAL(18,2)) AS TiempoEstanciaAbonadoNumero,
        CAST(NULL AS VARCHAR(100)) AS IdEquipoAbonado,
        CAST(NULL AS VARCHAR(100)) AS IdDimHorario

    FROM [TTV_DM].[dbo].[FactTicket] f
    WHERE
        UPPER(LTRIM(RTRIM(ISNULL(CAST(f.PAGOMANUAL_TIENEPAGOMANUAL AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
        AND (
                f.PAGOMANUAL_FECHA_COBRO >= @FechaInicio
            AND f.PAGOMANUAL_FECHA_COBRO <  @FechaFinExclusiva
            OR (
                    f.PAGOMANUAL_FECHA_COBRO IS NULL
                AND f.PAGOMANUAL_FECHA >= @FechaInicio
                AND f.PAGOMANUAL_FECHA <  @FechaFinExclusiva
               )
        )

    UNION ALL

    /* ============================================================
       4. TICKETS SIN PAGO
       ============================================================ */
    SELECT
        'TICKET' AS FuenteTTV,
        'TICKET SIN PAGO' AS TipoRegistro,
        'SIN PAGO' AS TipoMovimiento,

        CONCAT('TICKET-', CAST(f.TICKET_NUMERO AS VARCHAR(100)), '-SIN-PAGO') AS IdOperacionTTV,

        CAST(f.TICKET_NUMERO AS VARCHAR(100)) AS TICKET_NUMERO,
        f.TICKET_FECHA_HORA_EMISION,
        CAST(f.TICKET_TIPO_VEHICULO AS VARCHAR(100)) AS TICKET_TIPO_VEHICULO,
        CAST(f.TICKET_PLACA AS VARCHAR(100)) AS TICKET_PLACA,
        ISNULL(NULLIF(TRY_CONVERT(INT, f.TICKET_CANTIDADTICKETS), 0), 1) AS TICKET_CANTIDADTICKETS,

        f.CREACION_FECHA,
        CAST(f.CREACION_EQUIPO AS VARCHAR(100)) AS CREACION_EQUIPO,
        CAST(f.CREACION_ZONA AS VARCHAR(100)) AS CREACION_ZONA,

        f.ENTRADA_FECHA,
        CAST(f.ENTRADA_EQUIPO AS VARCHAR(100)) AS ENTRADA_EQUIPO,
        CAST(f.ENTRADA_ZONA AS VARCHAR(100)) AS ENTRADA_ZONA,

        f.SALIDA_FECHA,
        CAST(f.SALIDA_EQUIPO AS VARCHAR(100)) AS SALIDA_EQUIPO,
        CAST(f.SALIDA_ZONA AS VARCHAR(100)) AS SALIDA_ZONA,

        f.DESTRUCCION_FECHA,
        CAST(f.DESTRUCCION_EQUIPO AS VARCHAR(100)) AS DESTRUCCION_EQUIPO,
        CAST(f.DESTRUCCION_ZONA AS VARCHAR(100)) AS DESTRUCCION_ZONA,

        CAST(f.ANULACION_TIENE_ANULACION AS VARCHAR(30)) AS ANULACION_TIENE_ANULACION,
        f.ANULACION_FECHA_ANULACION,
        CAST(f.ANULACION_TIPO_ANULACION AS VARCHAR(200)) AS ANULACION_TIPO_ANULACION,

        COALESCE(f.ENTRADA_FECHA, f.TICKET_FECHA_HORA_EMISION, f.CREACION_FECHA) AS FechaAnalisis,
        CAST(NULL AS DATETIME) AS FechaPagoReal,
        COALESCE(f.ENTRADA_FECHA, f.TICKET_FECHA_HORA_EMISION, f.CREACION_FECHA) AS FechaOperacion,
        CAST(NULL AS DATETIME) AS FechaCobroSistema,

        CAST(NULL AS VARCHAR(100)) AS CodigoCaja,
        CAST(NULL AS VARCHAR(200)) AS CajaRecaudadoraOriginal,
        CAST(NULL AS VARCHAR(100)) AS ZonaCaja,

        CAST(NULL AS VARCHAR(100)) AS CodigoSistema,
        CAST(NULL AS VARCHAR(100)) AS OidEquipo,
        CAST(NULL AS VARCHAR(100)) AS CodigoPeriodoLocal,
        CAST(NULL AS VARCHAR(100)) AS CodigoCobro,

        CAST(0 AS INT) AS CantidadTicketsPagados,
        CAST(0 AS DECIMAL(18,2)) AS ValorPagado,
        CAST(0 AS DECIMAL(18,2)) AS ValorOperacion,

        CAST(NULL AS VARCHAR(100)) AS IdFactTarjetaAbonado,
        CAST(NULL AS VARCHAR(200)) AS ProductoAbonoContratado,
        CAST(NULL AS VARCHAR(300)) AS Cliente,
        CAST(NULL AS VARCHAR(100)) AS Tarjeta,
        CAST(NULL AS VARCHAR(100)) AS Matricula,
        CAST(NULL AS VARCHAR(100)) AS TiempoEstanciaAbonadoTexto,
        CAST(NULL AS DECIMAL(18,2)) AS TiempoEstanciaAbonadoNumero,
        CAST(NULL AS VARCHAR(100)) AS IdEquipoAbonado,
        CAST(NULL AS VARCHAR(100)) AS IdDimHorario

    FROM [TTV_DM].[dbo].[FactTicket] f
    WHERE
        UPPER(LTRIM(RTRIM(ISNULL(CAST(f.PAGO_TIENEPAGO AS VARCHAR(30)), '')))) NOT IN ('SI', 'S', '1', 'TRUE')
        AND UPPER(LTRIM(RTRIM(ISNULL(CAST(f.REPAGO_TIENEREPAGO AS VARCHAR(30)), '')))) NOT IN ('SI', 'S', '1', 'TRUE')
        AND UPPER(LTRIM(RTRIM(ISNULL(CAST(f.PAGOMANUAL_TIENEPAGOMANUAL AS VARCHAR(30)), '')))) NOT IN ('SI', 'S', '1', 'TRUE')
        AND COALESCE(f.ENTRADA_FECHA, f.TICKET_FECHA_HORA_EMISION, f.CREACION_FECHA) >= @FechaInicio
        AND COALESCE(f.ENTRADA_FECHA, f.TICKET_FECHA_HORA_EMISION, f.CREACION_FECHA) <  @FechaFinExclusiva

    UNION ALL

    /* ============================================================
       5. ABONADOS / TARJETAS
       ============================================================ */
    SELECT
        'ABONADO' AS FuenteTTV,
        'ABONADO' AS TipoRegistro,
        'TARJETA ABONADO' AS TipoMovimiento,

        CONCAT('ABONADO-', CAST(a.IdFactTarjetaAbonado AS VARCHAR(100))) AS IdOperacionTTV,

        CAST(NULL AS VARCHAR(100)) AS TICKET_NUMERO,
        a.FechaOperacion AS TICKET_FECHA_HORA_EMISION,
        CAST('ABONADO' AS VARCHAR(100)) AS TICKET_TIPO_VEHICULO,
        CAST(a.Matricula AS VARCHAR(100)) AS TICKET_PLACA,
        CAST(1 AS INT) AS TICKET_CANTIDADTICKETS,

        CAST(NULL AS DATETIME) AS CREACION_FECHA,
        CAST(NULL AS VARCHAR(100)) AS CREACION_EQUIPO,
        CAST(NULL AS VARCHAR(100)) AS CREACION_ZONA,

        CAST(NULL AS DATETIME) AS ENTRADA_FECHA,
        CAST(NULL AS VARCHAR(100)) AS ENTRADA_EQUIPO,
        CAST(a.ZonaEntrada AS VARCHAR(100)) AS ENTRADA_ZONA,

        CAST(NULL AS DATETIME) AS SALIDA_FECHA,
        CAST(NULL AS VARCHAR(100)) AS SALIDA_EQUIPO,
        CAST(a.ZonaSalida AS VARCHAR(100)) AS SALIDA_ZONA,

        CAST(NULL AS DATETIME) AS DESTRUCCION_FECHA,
        CAST(NULL AS VARCHAR(100)) AS DESTRUCCION_EQUIPO,
        CAST(NULL AS VARCHAR(100)) AS DESTRUCCION_ZONA,

        CAST(NULL AS VARCHAR(30)) AS ANULACION_TIENE_ANULACION,
        CAST(NULL AS DATETIME) AS ANULACION_FECHA_ANULACION,
        CAST(NULL AS VARCHAR(200)) AS ANULACION_TIPO_ANULACION,

        a.FechaOperacion AS FechaAnalisis,
        CAST(NULL AS DATETIME) AS FechaPagoReal,
        a.FechaOperacion AS FechaOperacion,
        CAST(NULL AS DATETIME) AS FechaCobroSistema,

        CAST(a.IdEquipo AS VARCHAR(100)) AS CodigoCaja,
        CAST(NULL AS VARCHAR(200)) AS CajaRecaudadoraOriginal,
        CAST(NULL AS VARCHAR(100)) AS ZonaCaja,

        CAST(NULL AS VARCHAR(100)) AS CodigoSistema,
        CAST(NULL AS VARCHAR(100)) AS OidEquipo,
        CAST(NULL AS VARCHAR(100)) AS CodigoPeriodoLocal,
        CAST(NULL AS VARCHAR(100)) AS CodigoCobro,

        CAST(0 AS INT) AS CantidadTicketsPagados,
        CAST(0 AS DECIMAL(18,2)) AS ValorPagado,
        CAST(0 AS DECIMAL(18,2)) AS ValorOperacion,

        CAST(a.IdFactTarjetaAbonado AS VARCHAR(100)) AS IdFactTarjetaAbonado,
        CAST(a.ProductoAbonoContratado AS VARCHAR(200)) AS ProductoAbonoContratado,
        CAST(a.Cliente AS VARCHAR(300)) AS Cliente,
        CAST(a.Tarjeta AS VARCHAR(100)) AS Tarjeta,
        CAST(a.Matricula AS VARCHAR(100)) AS Matricula,
        CAST(a.TiempoEstancia AS VARCHAR(100)) AS TiempoEstanciaAbonadoTexto,
        TRY_CONVERT(DECIMAL(18,2), a.TiempoEstancia) AS TiempoEstanciaAbonadoNumero,
        CAST(a.IdEquipo AS VARCHAR(100)) AS IdEquipoAbonado,
        CAST(a.IdDimHorario AS VARCHAR(100)) AS IdDimHorario

    FROM [TTV_DM].[dbo].[FactTarjetaAbonado] a
    WHERE
        a.FechaOperacion >= @FechaInicio
        AND a.FechaOperacion <  @FechaFinExclusiva
)

SELECT
    FuenteTTV,
    TipoRegistro,
    TipoMovimiento,
    IdOperacionTTV,

    TICKET_NUMERO,
    NULLIF(UPPER(LTRIM(RTRIM(ISNULL(TICKET_PLACA, '')))), '') AS Placa,
    UPPER(LTRIM(RTRIM(ISNULL(TICKET_TIPO_VEHICULO, 'SIN TIPO')))) AS TipoVehiculo,
    ISNULL(NULLIF(TICKET_CANTIDADTICKETS, 0), 1) AS CantidadTicketsOriginal,

    FechaAnalisis,
    CAST(FechaAnalisis AS DATE) AS Fecha,
    YEAR(FechaAnalisis) AS Anio,
    MONTH(FechaAnalisis) AS MesN,

    CASE MONTH(FechaAnalisis)
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END AS Mes,

    CONCAT(YEAR(FechaAnalisis), RIGHT('00' + CAST(MONTH(FechaAnalisis) AS VARCHAR(2)), 2)) AS AnioMes,

    ((DATEDIFF(DAY, '19000101', CAST(FechaAnalisis AS DATE)) % 7) + 1) AS DiaSemanaN,

    CASE ((DATEDIFF(DAY, '19000101', CAST(FechaAnalisis AS DATE)) % 7) + 1)
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS DiaSemana,

    DATEPART(HOUR, FechaAnalisis) AS Hora,

    RIGHT('00' + CAST(DATEPART(HOUR, FechaAnalisis) AS VARCHAR(2)), 2) + ':00' AS HoraTexto,

    RIGHT('00' + CAST(DATEPART(HOUR, FechaAnalisis) AS VARCHAR(2)), 2)
    + ':00 - ' +
    RIGHT('00' + CAST((DATEPART(HOUR, FechaAnalisis) + 1) % 24 AS VARCHAR(2)), 2)
    + ':00' AS RangoHora,

    CASE 
        WHEN DATEPART(HOUR, FechaAnalisis) BETWEEN 6 AND 13 THEN 'Turno 06:00 - 14:00'
        WHEN DATEPART(HOUR, FechaAnalisis) BETWEEN 14 AND 21 THEN 'Turno 14:00 - 22:00'
        ELSE 'Turno 22:00 - 06:00'
    END AS Turno,

    CASE 
        WHEN DATEPART(HOUR, FechaAnalisis) BETWEEN 0 AND 5
        THEN DATEADD(DAY, -1, CAST(FechaAnalisis AS DATE))
        ELSE CAST(FechaAnalisis AS DATE)
    END AS FechaOperativa,

    TICKET_FECHA_HORA_EMISION,
    CREACION_FECHA,
    ENTRADA_FECHA,
    FechaPagoReal,
    FechaOperacion,
    FechaCobroSistema,
    SALIDA_FECHA,

    CREACION_EQUIPO,
    CREACION_ZONA,
    ENTRADA_EQUIPO,
    ENTRADA_ZONA,
    SALIDA_EQUIPO,
    SALIDA_ZONA,

    CodigoCaja,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND CajaRecaudadoraOriginal IS NOT NULL 
             AND LTRIM(RTRIM(CajaRecaudadoraOriginal)) <> ''
        THEN UPPER(LTRIM(RTRIM(CajaRecaudadoraOriginal)))

        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND CodigoCaja IS NOT NULL 
             AND LTRIM(RTRIM(CodigoCaja)) <> ''
        THEN CONCAT('CAJA ', UPPER(LTRIM(RTRIM(CodigoCaja))))

        WHEN TipoRegistro = 'ABONADO'
             AND CodigoCaja IS NOT NULL
             AND LTRIM(RTRIM(CodigoCaja)) <> ''
        THEN CONCAT('EQUIPO ABONADO ', UPPER(LTRIM(RTRIM(CodigoCaja))))

        ELSE 'SIN CAJA / EQUIPO IDENTIFICADO'
    END AS CajaEquipo,

    CASE 
        WHEN ZonaCaja IS NOT NULL 
             AND LTRIM(RTRIM(ZonaCaja)) <> ''
        THEN UPPER(LTRIM(RTRIM(ZonaCaja)))
        ELSE 'SIN ZONA DE CAJA'
    END AS ZonaCaja,

    CodigoSistema,
    OidEquipo,
    CodigoPeriodoLocal,
    CodigoCobro,

    CantidadTicketsPagados,

    CAST(ValorPagado AS DECIMAL(18,2)) AS ValorPagadoBruto,
    CAST(ValorOperacion AS DECIMAL(18,2)) AS ValorOperacion,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND (
                    UPPER(LTRIM(RTRIM(ISNULL(CAST(ANULACION_TIENE_ANULACION AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
                    OR ANULACION_FECHA_ANULACION IS NOT NULL
                 )
        THEN CAST(0 AS DECIMAL(18,2))

        WHEN TipoRegistro = 'EVENTO DE CAJA'
        THEN CAST(ValorPagado AS DECIMAL(18,2))

        ELSE CAST(0 AS DECIMAL(18,2))
    END AS ValorPagadoValido,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND (
                    UPPER(LTRIM(RTRIM(ISNULL(CAST(ANULACION_TIENE_ANULACION AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
                    OR ANULACION_FECHA_ANULACION IS NOT NULL
                 )
        THEN CAST(ValorPagado AS DECIMAL(18,2))
        ELSE CAST(0 AS DECIMAL(18,2))
    END AS ValorPagadoAnulado,

    CASE 
        WHEN ENTRADA_FECHA IS NOT NULL AND SALIDA_FECHA IS NOT NULL
        THEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA)
    END AS DuracionMinutosDentroTTV,

    CAST(
        CASE 
            WHEN ENTRADA_FECHA IS NOT NULL AND SALIDA_FECHA IS NOT NULL
            THEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) / 60.0
        END AS DECIMAL(18,2)
    ) AS DuracionHorasDentroTTV,

    CASE 
        WHEN ENTRADA_FECHA IS NOT NULL AND FechaPagoReal IS NOT NULL
        THEN DATEDIFF(MINUTE, ENTRADA_FECHA, FechaPagoReal)
    END AS MinutosEntradaHastaPago,

    CASE 
        WHEN FechaPagoReal IS NOT NULL AND SALIDA_FECHA IS NOT NULL
        THEN DATEDIFF(MINUTE, FechaPagoReal, SALIDA_FECHA)
    END AS MinutosPagoHastaSalida,

    CASE 
        WHEN TICKET_FECHA_HORA_EMISION IS NOT NULL AND FechaPagoReal IS NOT NULL
        THEN DATEDIFF(MINUTE, TICKET_FECHA_HORA_EMISION, FechaPagoReal)
    END AS MinutosEmisionHastaPago,

    CASE 
        WHEN ENTRADA_FECHA IS NOT NULL AND SALIDA_FECHA IS NOT NULL THEN
            CASE
                WHEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) < 30 THEN 'MENOS DE 30 MIN'
                WHEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) BETWEEN 30 AND 59 THEN '30 A 59 MIN'
                WHEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) BETWEEN 60 AND 119 THEN '1 A 2 HORAS'
                WHEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) BETWEEN 120 AND 239 THEN '2 A 4 HORAS'
                WHEN DATEDIFF(MINUTE, ENTRADA_FECHA, SALIDA_FECHA) >= 240 THEN 'MÁS DE 4 HORAS'
            END
        ELSE 'SIN DURACIÓN COMPLETA'
    END AS RangoEstancia,

    DESTRUCCION_FECHA,
    DESTRUCCION_EQUIPO,
    DESTRUCCION_ZONA,

    ANULACION_TIENE_ANULACION,
    ANULACION_FECHA_ANULACION,
    ANULACION_TIPO_ANULACION,

    CASE 
        WHEN UPPER(LTRIM(RTRIM(ISNULL(CAST(ANULACION_TIENE_ANULACION AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
          OR ANULACION_FECHA_ANULACION IS NOT NULL
        THEN 1 ELSE 0 
    END AS FlagAnulado,

    CASE 
        WHEN TipoRegistro = 'ABONADO'
        THEN 'MOVIMIENTO ABONADO'

        WHEN UPPER(LTRIM(RTRIM(ISNULL(CAST(ANULACION_TIENE_ANULACION AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
          OR ANULACION_FECHA_ANULACION IS NOT NULL
        THEN 'ANULADO'

        WHEN DESTRUCCION_FECHA IS NOT NULL
        THEN 'DESTRUIDO'

        WHEN TipoRegistro = 'TICKET SIN PAGO' AND SALIDA_FECHA IS NOT NULL
        THEN 'SALIDO SIN PAGO'

        WHEN TipoRegistro = 'TICKET SIN PAGO' AND ENTRADA_FECHA IS NOT NULL
        THEN 'INGRESADO SIN PAGO'

        WHEN TipoRegistro = 'EVENTO DE CAJA' AND SALIDA_FECHA IS NOT NULL
        THEN 'PAGADO Y SALIÓ'

        WHEN TipoRegistro = 'EVENTO DE CAJA' AND FechaPagoReal IS NOT NULL
        THEN 'PAGADO SIN SALIDA'

        ELSE 'SIN ESTADO COMPLETO'
    END AS EstadoOperativoTTV,

    CASE WHEN TipoRegistro = 'EVENTO DE CAJA' THEN 1 ELSE 0 END AS FlagEventoCaja,
    CASE WHEN TipoRegistro = 'TICKET SIN PAGO' THEN 1 ELSE 0 END AS FlagTicketSinPago,
    CASE WHEN TipoRegistro = 'ABONADO' THEN 1 ELSE 0 END AS FlagAbonado,

    CASE 
        WHEN TipoRegistro = 'TICKET SIN PAGO'
        THEN ISNULL(NULLIF(TICKET_CANTIDADTICKETS, 0), 1)
        ELSE 0
    END AS CantidadTicketsSinPago,

    CASE 
        WHEN TipoRegistro = 'ABONADO'
        THEN 1
        ELSE 0
    END AS CantidadMovimientosAbonados,

    IdFactTarjetaAbonado,
    ProductoAbonoContratado,
    Cliente,
    Tarjeta,
    Matricula,
    TiempoEstanciaAbonadoTexto,
    TiempoEstanciaAbonadoNumero,
    IdEquipoAbonado,
    IdDimHorario,

    CASE WHEN FuenteTTV = 'TICKET' AND ENTRADA_FECHA IS NULL THEN 1 ELSE 0 END AS AlertaSinEntrada,
    CASE WHEN FuenteTTV = 'TICKET' AND SALIDA_FECHA IS NULL THEN 1 ELSE 0 END AS AlertaSinSalida,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA' AND FechaPagoReal IS NULL 
        THEN 1 ELSE 0 
    END AS AlertaSinFechaPago,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND (CodigoCaja IS NULL OR LTRIM(RTRIM(CodigoCaja)) = '')
        THEN 1 ELSE 0 
    END AS AlertaSinCodigoCaja,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND (CajaRecaudadoraOriginal IS NULL OR LTRIM(RTRIM(CajaRecaudadoraOriginal)) = '')
        THEN 1 ELSE 0 
    END AS AlertaSinNombreCaja,

    CASE 
        WHEN FuenteTTV IN ('TICKET', 'ABONADO')
             AND (TICKET_PLACA IS NULL OR LTRIM(RTRIM(TICKET_PLACA)) = '')
        THEN 1 ELSE 0 
    END AS AlertaSinPlaca,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND ValorPagado <= 0 
        THEN 1 ELSE 0 
    END AS AlertaValorPagadoCeroNegativo,

    CASE 
        WHEN ENTRADA_FECHA IS NOT NULL 
         AND FechaPagoReal IS NOT NULL 
         AND FechaPagoReal < ENTRADA_FECHA
        THEN 1 ELSE 0 
    END AS AlertaPagoAntesEntrada,

    CASE 
        WHEN SALIDA_FECHA IS NOT NULL 
         AND FechaPagoReal IS NOT NULL 
         AND SALIDA_FECHA < FechaPagoReal
        THEN 1 ELSE 0 
    END AS AlertaSalidaAntesPago,

    CASE 
        WHEN ENTRADA_FECHA IS NOT NULL 
         AND SALIDA_FECHA IS NOT NULL
         AND SALIDA_FECHA < ENTRADA_FECHA
        THEN 1 ELSE 0 
    END AS AlertaSalidaAntesEntrada,

    CASE 
        WHEN TipoRegistro = 'EVENTO DE CAJA'
             AND (
                    UPPER(LTRIM(RTRIM(ISNULL(CAST(ANULACION_TIENE_ANULACION AS VARCHAR(30)), '')))) IN ('SI', 'S', '1', 'TRUE')
                    OR ANULACION_FECHA_ANULACION IS NOT NULL
                 )
             AND ValorPagado > 0
        THEN 1 ELSE 0 
    END AS AlertaAnuladoConValorPagado

FROM BaseEventosTTV;
