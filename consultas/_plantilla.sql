/*
 * ============================================================================
 * CONSULTA: <nombre de la consulta>
 * ----------------------------------------------------------------------------
 * Dashboard / sistema : <nombre del dashboard o del sistema>
 * Página / destino    : <página del dashboard o tabla de destino>
 * Qué responde        : <una o dos frases>
 * Bases de origen     : <BASE_DM: tablas principales>
 * Granularidad        : <una fila por ...>
 * Motor               : SQL Server (data warehouse municipal)
 * Versión             : AAAA-MM
 * Autor               : <nombre y cargo>
 * Publicación         : versión sanitizada. Sin datos de contribuyentes ni credenciales.
 * Antes de ejecutar   : <marcadores que deben completarse, por ejemplo <servidor>>
 * ============================================================================
 */

-- Reglas de sanitización antes de subir al repositorio:
--   * Servidor y cadenas de conexión  -> <servidor>
--   * RUC, cédulas y nombres reales   -> <RUC_1>, <NOMBRE>
--   * Totales o resultados reales en comentarios -> <total>
--   * Nombre del archivo: tema_vAAAAMM.sql, en minúsculas y con guiones.

SELECT 1 AS Ejemplo;
