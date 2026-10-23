-- Ingeniería de features históricas para inasistencia a turnos médicos
-- Las variables de cada cita utilizan únicamente información de fechas anteriores.

WITH appointments_base AS (
    SELECT
        TRY_CAST(PatientId AS BIGINT) AS patient_id,
        TRY_CAST(AppointmentID AS BIGINT) AS appointment_id,
        CAST(TRY_CAST(AppointmentDay AS TIMESTAMP) AS DATE) AS appointment_date,
        CAST(TRY_CAST(ScheduledDay AS TIMESTAMP) AS DATE) AS scheduled_date,
        CASE
            WHEN "No-show" = 'Yes' THEN 1
            WHEN "No-show" = 'No' THEN 0
            ELSE NULL
        END AS no_show
    FROM appointments
),

-- Excluir registros sin identificadores o fechas válidas,
-- y citas cuya fecha sea anterior a la fecha de programación.
valid_appointments AS (
    SELECT *
    FROM appointments_base
    WHERE patient_id IS NOT NULL
      AND appointment_id IS NOT NULL
      AND appointment_date IS NOT NULL
      AND scheduled_date IS NOT NULL
      AND appointment_date >= scheduled_date
      AND no_show IS NOT NULL
),

-- Agrupar por paciente y día para que las citas del mismo día
-- compartan el mismo historial previo.
daily_history AS (
    SELECT
        patient_id,
        appointment_date,
        COUNT(*) AS visits_on_day,
        SUM(no_show) AS no_shows_on_day
    FROM valid_appointments
    GROUP BY patient_id, appointment_date
),

-- Calcular las métricas utilizando solo días anteriores.
daily_features AS (
    SELECT
        patient_id,
        appointment_date,

        LAG(appointment_date) OVER (
            PARTITION BY patient_id
            ORDER BY appointment_date
        ) AS previous_appointment_date,

        SUM(visits_on_day) OVER (
            PARTITION BY patient_id
            ORDER BY appointment_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_visit_count,

        SUM(no_shows_on_day) OVER (
            PARTITION BY patient_id
            ORDER BY appointment_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_no_show_count,

        SUM(visits_on_day) OVER (
            PARTITION BY patient_id
            ORDER BY appointment_date
            RANGE BETWEEN INTERVAL 30 DAYS PRECEDING
                      AND INTERVAL 1 DAY PRECEDING
        ) AS visits_last_30_days,

        SUM(visits_on_day) OVER (
            PARTITION BY patient_id
            ORDER BY appointment_date
            RANGE BETWEEN INTERVAL 60 DAYS PRECEDING
                      AND INTERVAL 31 DAYS PRECEDING
        ) AS visits_previous_30_days

    FROM daily_history
),

-- Asociar las métricas históricas a cada cita.
features AS (
    SELECT
        a.patient_id,
        a.appointment_id,
        a.scheduled_date,
        a.appointment_date,
        a.no_show,

        DATE_DIFF(
            'day',
            f.previous_appointment_date,
            a.appointment_date
        ) AS recency_days,

        COALESCE(f.previous_visit_count, 0) AS frequency,

        CASE
            WHEN f.previous_visit_count > 0
            THEN
                f.previous_no_show_count * 1.0
                / f.previous_visit_count
            ELSE NULL
        END AS historical_no_show_rate,

        COALESCE(f.visits_last_30_days, 0) AS visits_last_30_days,

        COALESCE(f.visits_previous_30_days, 0)
            AS visits_previous_30_days,

        COALESCE(f.visits_last_30_days, 0)
        - COALESCE(f.visits_previous_30_days, 0)
            AS visit_trend

    FROM valid_appointments AS a
    INNER JOIN daily_features AS f
        ON a.patient_id = f.patient_id
       AND a.appointment_date = f.appointment_date
)

SELECT *
FROM features
ORDER BY patient_id, appointment_date, appointment_id;