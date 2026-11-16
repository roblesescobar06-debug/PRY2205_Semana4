/* =====================================================================
   PRY2205 - CONSULTA DE BASES DE DATOS
   SEMANA 4 - ACTIVIDAD FORMATIVA: "DESARROLLANDO JOINS EN LAS TABLAS"
   Caso: Conciertos Chile S.A.
   Grupo 12: Betina Elena Salinas Rojas - Cristobal Alejandro Robles Escobar
   Usuario BD: PRY2205_S4 / Conexion: PRY2205_ACTIVIDAD_S4
   ---------------------------------------------------------------------
   PASOS PREVIOS:
     1. Conectado como SYS/SYSTEM (o ADMIN en Oracle Cloud) se ejecuta el
        script PRY2205_Exp2_S4_Script_crea_usuario.sql, que crea al
        usuario PRY2205_S4.
     2. Se crea la conexion PRY2205_ACTIVIDAD_S4 con ese usuario.
     3. Conectado con PRY2205_S4 se ejecuta el script
        PRY2205_Exp2_S4_CreaEsquemaPoblado.sql, que crea y pobla las
        tablas del modelo relacional.
   ===================================================================== */

-- Formato numerico chileno: punto como separador de miles.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';


/* =====================================================================
   CASO 1: LISTADO DE TRABAJADORES
   ---------------------------------------------------------------------
   Lista el nombre completo, el RUT, el tipo de trabajador, la ciudad y
   el sueldo base de los trabajadores cuyo sueldo base se encuentra
   entre $650.000 y $3.000.000.
   Ordenado por nombre de ciudad en forma descendente y por sueldo base
   en forma ascendente.
   JOINS: TRABAJADOR - TIPO_TRABAJADOR - COMUNA_CIUDAD
   ===================================================================== */
SELECT UPPER(t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno)   AS "Nombre Completo Trabajador",
       LTRIM(TO_CHAR(t.numrut, '99G999G999')) || '-' || t.dvrut      AS "RUT Trabajador",
       UPPER(tt.desc_categoria)                                      AS "Tipo Trabajador",
       UPPER(cc.nombre_ciudad)                                       AS "Ciudad Trabajador",
       TO_CHAR(NVL(t.sueldo_base, 0), '$9G999G999')                  AS "Sueldo Base"
FROM   trabajador t
       JOIN tipo_trabajador tt ON t.id_categoria_t = tt.id_categoria
       JOIN comuna_ciudad   cc ON t.id_ciudad      = cc.id_ciudad
WHERE  t.sueldo_base BETWEEN 650000 AND 3000000
ORDER  BY cc.nombre_ciudad DESC,
          t.sueldo_base    ASC;


/* =====================================================================
   CASO 2: LISTADO DE CAJEROS
   ---------------------------------------------------------------------
   Bitacora de los trabajadores con rol CAJERO que han vendido tickets:
   cantidad de tickets vendidos, total vendido, comision total, tipo de
   trabajador y comuna del trabajador.
   Solo se muestran los cajeros cuya suma de montos de tickets supera
   los $50.000.
   Ordenado por total vendido en forma descendente.
   JOINS: TRABAJADOR - TIPO_TRABAJADOR - COMUNA_CIUDAD -
          TICKETS_CONCIERTO - COMISIONES_TICKET
   ===================================================================== */
SELECT LTRIM(TO_CHAR(t.numrut, '99G999G999')) || '-' || t.dvrut      AS "RUT Trabajador",
       INITCAP(t.nombre) || ' ' || UPPER(t.appaterno)                AS "Nombre Trabajador",
       COUNT(tk.nro_ticket)                                          AS "Total Tickets",
       TO_CHAR(SUM(NVL(tk.monto_ticket, 0)), '$9G999G999')           AS "Total Vendido",
       TO_CHAR(SUM(NVL(ct.valor_comision, 0)), '$9G999G999')         AS "Comisión Total",
       UPPER(tt.desc_categoria)                                      AS "Tipo Trabajador",
       UPPER(cc.nombre_ciudad)                                       AS "Ciudad Trabajador"
FROM   trabajador t
       JOIN tipo_trabajador    tt ON t.id_categoria_t = tt.id_categoria
       JOIN comuna_ciudad      cc ON t.id_ciudad      = cc.id_ciudad
       JOIN tickets_concierto  tk ON tk.numrut_t      = t.numrut
       LEFT JOIN comisiones_ticket ct ON ct.nro_ticket = tk.nro_ticket
WHERE  UPPER(tt.desc_categoria) = 'CAJERO'
GROUP  BY t.numrut, t.dvrut, t.nombre, t.appaterno,
          tt.desc_categoria, cc.nombre_ciudad
HAVING SUM(NVL(tk.monto_ticket, 0)) > 50000
ORDER  BY SUM(NVL(tk.monto_ticket, 0)) DESC;


/* =====================================================================
   CASO 3: LISTADO DE BONIFICACIONES
   ---------------------------------------------------------------------
   Muestra por trabajador el anio de ingreso, los anios de antiguedad,
   la cantidad de cargas familiares, el sistema de salud, el sueldo base,
   el bono FONASA, el bono por antiguedad, la AFP y el estado civil.
     - Bono FONASA : 1% del sueldo si el trabajador esta en FONASA;
                     en caso contrario no se asigna bono extra.
     - Bono antiguedad: 10% del sueldo con 10 o menos anios trabajados,
                     15% del sueldo con 11 o mas anios trabajados.
   Solo se consideran los trabajadores sin fecha de termino de estado
   civil, o cuya fecha de termino es posterior a la fecha de ejecucion
   del reporte (SYSDATE, sin fechas fijas).
   Ordenado por RUT en forma ascendente.
   JOINS: TRABAJADOR - isapre - AFP - EST_CIVIL - estado_civil -
          ASIGNACION_FAMILIAR
   ===================================================================== */
SELECT LTRIM(TO_CHAR(t.numrut, '99G999G999'))                        AS "RUT Trabajador",
       INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno)              AS "Trabajador Nombre",
       EXTRACT(YEAR FROM t.fecing)                                   AS "Año Ingreso",
       EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM t.fecing)      AS "Años Antigüedad",
       COUNT(af.numrut_carga)                                        AS "Num. Cargas Familiares",
       LPAD(INITCAP(i.nombre_isapre), 11)                            AS "Nombre Isapre",
       TO_CHAR(NVL(t.sueldo_base, 0), '$9G999G999')                  AS "Sueldo Base",
       CASE
            WHEN UPPER(i.nombre_isapre) = 'FONASA'
            THEN TO_CHAR(ROUND(NVL(t.sueldo_base, 0) * 1 / 100), '$9G999G999')
            ELSE LPAD('0', 11)
       END                                                           AS "Bono Fonasa",
       TO_CHAR(ROUND(NVL(t.sueldo_base, 0) *
                     CASE
                          WHEN EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM t.fecing) <= 10
                          THEN 10
                          ELSE 15
                     END / 100), '$9G999G999')                       AS "Bono Antigüedad",
       INITCAP(a.nombre_afp)                                         AS "Nombre AFP",
       UPPER(ec.desc_estcivil)                                       AS "Estado Civil"
FROM   trabajador t
       JOIN isapre       i   ON t.cod_isapre      = i.cod_isapre
       JOIN afp          a   ON t.cod_afp         = a.cod_afp
       JOIN est_civil    ecv ON ecv.numrut_t      = t.numrut
       JOIN estado_civil ec  ON ecv.id_estcivil_est = ec.id_estcivil
       LEFT JOIN asignacion_familiar af ON af.numrut_t = t.numrut
WHERE  (ecv.fecter_estcivil IS NULL
        OR ecv.fecter_estcivil > SYSDATE)
GROUP  BY t.numrut, t.nombre, t.appaterno, t.fecing, t.sueldo_base,
          i.nombre_isapre, a.nombre_afp, ec.desc_estcivil
ORDER  BY t.numrut ASC;
