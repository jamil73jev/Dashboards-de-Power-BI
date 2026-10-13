/*
 * ============================================================================
 * CONSULTA: recaudacion coactiva
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : Recaudación Municipal: Tablero Ejecutivo
 * Página / destino    : COACTIVA
 * Qué responde        : Recaudación de la coactiva reconocida por fecha de pago: bruta, ajustes negativos y neta, con sus componentes (deuda, intereses, coactiva, costas, descuentos).
 * Bases de origen     : COACTIVA_DM: DetalleJuicioCoactivoDW, JuicioCoactivaDW
 * Granularidad        : Mes + Juzgado + Tipo de ingreso
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : 2026-10
 * Autor               : Jorge Jamil Espinoza Villa, Analista Financiero
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * ============================================================================
 */

USE COACTIVA_DM;

/*======================================================================
    FACT RECAUDACION COACTIVA
    QUERY MAESTRO PRODUCTIVO

    FUENTES:
        dbo.DetalleJuicioCoactivoDW
        dbo.JuicioCoactivaDW

    UNIVERSO:
        IdEstado = 'C'
        CANCELADO CON COACTIVA

    FECHA DE RECONOCIMIENTO:
        DetalleJuicio_FechaPago

    GRANULARIDAD:
        Mes + Juzgado + TipoIngreso

    OBJETIVO:
        Fuente financiera principal para Power BI
======================================================================*/


/*======================================================================
    0. PARAMETROS
======================================================================*/

DECLARE @FechaDesde DATE = '2023-01-01';

DECLARE @FechaCorte DATETIME2(0) =
    SYSDATETIME();

DECLARE @InicioMesActual DATE =
    DATEFROMPARTS(
        YEAR(@FechaCorte),
        MONTH(@FechaCorte),
        1
    );


/*======================================================================
    1. BASE FILTRADA
======================================================================*/

WITH Base AS
(
    SELECT

        /*--------------------------------------------------------------
          FECHA MES
        --------------------------------------------------------------*/
        DATEFROMPARTS(
            YEAR(D.DetalleJuicio_FechaPago),
            MONTH(D.DetalleJuicio_FechaPago),
            1
        ) AS FechaMes,


        /*--------------------------------------------------------------
          JUZGADO
        --------------------------------------------------------------*/
        J.Juzgado,


        /*--------------------------------------------------------------
          TIPO DE INGRESO
        --------------------------------------------------------------*/
        J.TipoIngreso,


        TRY_CONVERT(
            TINYINT,
            LEFT(
                J.TipoIngreso,
                CHARINDEX(
                    ' ',
                    J.TipoIngreso + ' '
                ) - 1
            )
        ) AS CodigoTipoIngreso,


        /*--------------------------------------------------------------
          MONTO TOTAL
        --------------------------------------------------------------*/
        D.DetalleJuicio_MontoPago
            AS MontoPago,


        /*--------------------------------------------------------------
          COMPONENTES
        --------------------------------------------------------------*/
        ISNULL(
            D.DetalleJuicio_MontoPagoDeuda,
            0
        ) AS MontoPagoDeuda,


        ISNULL(
            D.DetalleJuicio_MontoPagoInteres,
            0
        ) AS MontoPagoInteres,


        ISNULL(
            D.DetalleJuicio_MontoPagoCoactiva,
            0
        ) AS MontoPagoCoactiva,


        ISNULL(
            D.Pago_Costas,
            0
        ) AS PagoCostas,


        ISNULL(
            D.DetalleJuicio_MontoPagoDescuento,
            0
        ) AS MontoPagoDescuento


    FROM dbo.DetalleJuicioCoactivoDW AS D

    INNER JOIN dbo.JuicioCoactivaDW AS J
        ON J.IdSecuenciaJuicio =
           D.IdSecuenciaJuicio


    WHERE

        /*--------------------------------------------------------------
          PERIODO
        --------------------------------------------------------------*/
        D.DetalleJuicio_FechaPago >= @FechaDesde

        AND D.DetalleJuicio_FechaPago <
            @FechaCorte


        /*--------------------------------------------------------------
          COBROS + AJUSTES
        --------------------------------------------------------------*/
        AND D.DetalleJuicio_MontoPago <> 0


        /*--------------------------------------------------------------
          SOLO CANCELADOS CON COACTIVA
        --------------------------------------------------------------*/
        AND J.IdEstado = 'C'


        /*--------------------------------------------------------------
          JUZGADOS VALIDOS
        --------------------------------------------------------------*/
        AND J.Juzgado IN
        (
            'PRIMERO',
            'SEGUNDO',
            'TERCERO',
            'CUARTO'
        )
),


/*======================================================================
    2. AGREGACION
======================================================================*/

Resumen AS
(
    SELECT

        FechaMes,

        Juzgado,

        CodigoTipoIngreso,

        TipoIngreso,


        /*==============================================================
          RECAUDACION BRUTA
        ==============================================================*/
        SUM(
            CASE
                WHEN MontoPago > 0
                    THEN MontoPago
                ELSE 0
            END
        ) AS RecaudacionBruta,


        /*==============================================================
          AJUSTES NEGATIVOS
        ==============================================================*/
        SUM(
            CASE
                WHEN MontoPago < 0
                    THEN MontoPago
                ELSE 0
            END
        ) AS AjustesNegativos,


        /*==============================================================
          RECAUDACION NETA
        ==============================================================*/
        SUM(
            MontoPago
        ) AS RecaudacionNeta,


        /*==============================================================
          COMPONENTES
        ==============================================================*/
        SUM(
            MontoPagoDeuda
        ) AS DeudaRecuperada,


        SUM(
            MontoPagoInteres
        ) AS InteresesCobrados,


        SUM(
            MontoPagoCoactiva
        ) AS ComponenteCoactiva,


        SUM(
            PagoCostas
        ) AS CostasCobradas,


        SUM(
            MontoPagoDescuento
        ) AS DescuentosRegistrados,


        /*==============================================================
          VOLUMEN
        ==============================================================*/
        COUNT_BIG(*)
            AS RegistrosConMovimiento,


        SUM(
            CASE
                WHEN MontoPago > 0
                    THEN 1
                ELSE 0
            END
        ) AS RegistrosPositivos,


        SUM(
            CASE
                WHEN MontoPago < 0
                    THEN 1
                ELSE 0
            END
        ) AS RegistrosNegativos


    FROM Base


    GROUP BY

        FechaMes,

        Juzgado,

        CodigoTipoIngreso,

        TipoIngreso
)


/*======================================================================
    3. RESULTADO FINAL
======================================================================*/

SELECT

    /*==================================================================
      CALENDARIO
    ==================================================================*/

    FechaMes,


    YEAR(FechaMes)
        AS Anio,


    YEAR(FechaMes) * 100
        + MONTH(FechaMes)
        AS PeriodoYYYYMM,


    CASE
        WHEN MONTH(FechaMes) <= 6
            THEN 1
        ELSE 2
    END AS NumeroSemestre,


    CASE
        WHEN MONTH(FechaMes) <= 6
            THEN 'Primer Semestre'
        ELSE
            'Segundo Semestre'
    END AS Semestre,


    DATEPART(
        QUARTER,
        FechaMes
    ) AS NumeroTrimestre,


    CONCAT(
        'T',
        DATEPART(
            QUARTER,
            FechaMes
        )
    ) AS Trimestre,


    MONTH(FechaMes)
        AS NumeroMes,


    CASE MONTH(FechaMes)

        WHEN 1  THEN 'Enero'
        WHEN 2  THEN 'Febrero'
        WHEN 3  THEN 'Marzo'
        WHEN 4  THEN 'Abril'
        WHEN 5  THEN 'Mayo'
        WHEN 6  THEN 'Junio'
        WHEN 7  THEN 'Julio'
        WHEN 8  THEN 'Agosto'
        WHEN 9  THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'

    END AS Mes,


    CONCAT(
        CASE MONTH(FechaMes)

            WHEN 1  THEN 'Enero'
            WHEN 2  THEN 'Febrero'
            WHEN 3  THEN 'Marzo'
            WHEN 4  THEN 'Abril'
            WHEN 5  THEN 'Mayo'
            WHEN 6  THEN 'Junio'
            WHEN 7  THEN 'Julio'
            WHEN 8  THEN 'Agosto'
            WHEN 9  THEN 'Septiembre'
            WHEN 10 THEN 'Octubre'
            WHEN 11 THEN 'Noviembre'
            WHEN 12 THEN 'Diciembre'

        END,
        ' ',
        YEAR(FechaMes)
    ) AS MesAnio,


    /*==================================================================
      ESTADO DEL PERIODO
    ==================================================================*/

    CASE
        WHEN FechaMes < @InicioMesActual
            THEN 1
        ELSE 0
    END AS EsMesCerrado,


    CASE
        WHEN FechaMes < @InicioMesActual
            THEN 'MES CERRADO'
        ELSE
            'MES EN CURSO'
    END AS EstadoPeriodo,


    /*==================================================================
      JUZGADO
    ==================================================================*/

    CASE Juzgado
        WHEN 'PRIMERO' THEN 1
        WHEN 'SEGUNDO' THEN 2
        WHEN 'TERCERO' THEN 3
        WHEN 'CUARTO' THEN 4
    END AS OrdenJuzgado,


    CASE Juzgado
        WHEN 'PRIMERO' THEN 'JUZGADO PRIMERO'
        WHEN 'SEGUNDO' THEN 'JUZGADO SEGUNDO'
        WHEN 'TERCERO' THEN 'JUZGADO TERCERO'
        WHEN 'CUARTO' THEN 'JUZGADO CUARTO'
    END AS Juzgado,


    /*==================================================================
      CLASIFICACION
    ==================================================================*/

    CASE

        WHEN CodigoTipoIngreso IN (1,2,3,4,7)
            THEN 1

        WHEN CodigoTipoIngreso IN (5,6)
            THEN 2

        ELSE 3

    END AS OrdenGrupoIngreso,


    CASE

        WHEN CodigoTipoIngreso IN (1,2,3,4,7)
            THEN 'PREDIALES'

        WHEN CodigoTipoIngreso IN (5,6)
            THEN 'NO PREDIALES'

        ELSE
            'OTROS'

    END AS GrupoIngreso,


    CodigoTipoIngreso,

    TipoIngreso,


    /*==================================================================
      RECAUDACION
    ==================================================================*/

    CAST(
        RecaudacionBruta
        AS DECIMAL(19,2)
    ) AS RecaudacionBruta,


    CAST(
        AjustesNegativos
        AS DECIMAL(19,2)
    ) AS AjustesNegativos,


    CAST(
        RecaudacionNeta
        AS DECIMAL(19,2)
    ) AS RecaudacionNeta,


    /*==================================================================
      COMPONENTES
    ==================================================================*/

    CAST(
        DeudaRecuperada
        AS DECIMAL(19,2)
    ) AS DeudaRecuperada,


    CAST(
        InteresesCobrados
        AS DECIMAL(19,2)
    ) AS InteresesCobrados,


    CAST(
        ComponenteCoactiva
        AS DECIMAL(19,2)
    ) AS ComponenteCoactiva,


    CAST(
        CostasCobradas
        AS DECIMAL(19,2)
    ) AS CostasCobradas,


    CAST(
        DescuentosRegistrados
        AS DECIMAL(19,2)
    ) AS DescuentosRegistrados,


    /*==================================================================
      VOLUMEN
    ==================================================================*/

    RegistrosConMovimiento,

    RegistrosPositivos,

    RegistrosNegativos


FROM Resumen;
