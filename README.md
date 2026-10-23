# Patient Attendance — Feature Engineering with SQL

## 1. Descripción del proyecto

Proyecto de ingeniería de features mediante SQL analítico y DuckDB, aplicado al análisis de inasistencias a citas médicas.

El objetivo es construir variables históricas por paciente que permitan estudiar la relación entre su comportamiento previo y la inasistencia a una cita posterior.

**Pregunta de análisis:** ¿Qué patrones históricos de asistencia pueden ayudar a caracterizar el riesgo de inasistencia a un turno médico?

## 2. Fuente de datos

* **Dataset:** Medical Appointment No Shows.
* **Fuente:** [Kaggle — Medical Appointment No Shows](https://www.kaggle.com/datasets/joniarroba/noshowappointments).
* **Archivo:** `KaggleV2-May-2016.csv`.
* **Unidad de observación:** una cita médica programada.
* **Variable objetivo:** `No-show`, que indica si el paciente faltó a la cita.

El dataset contiene información sobre pacientes, fechas de programación y de atención, características demográficas y resultados de las citas.

## 3. Justificación y adaptación de la consigna

La consigna original propone calcular métricas de comportamiento como Recency, Frequency, Monetary y Trend, utilizando funciones de ventana SQL.

Se seleccionó un dataset del ámbito de salud para aplicar estos conceptos a un problema relacionado con la asistencia a citas médicas.

Las variables se adaptaron de la siguiente manera:

| Métrica                                 | Feature                   | Lógica                                                                                     |
| --------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------ |
| Recency                                 | `recency_days`            | Días desde la cita anterior del paciente.                                                  |
| Frequency                               | `frequency`               | Cantidad de citas anteriores.                                                              |
| Adaptación de comportamiento a Monetary | `historical_no_show_rate` | Proporción de citas anteriores con inasistencia. No representa una métrica monetaria.      |
| Trend                                   | `visit_trend`             | Diferencia entre las visitas de los últimos 30 días y las del período de 30 días anterior. |

El dataset no contiene gastos ni transacciones económicas, por lo que no es posible calcular Monetary de manera válida. En su lugar, se incorpora una métrica histórica relacionada con el comportamiento de asistencia, explicando explícitamente esta adaptación.

## 4. Metodología SQL

Las transformaciones se implementan en `sql/feature_engineering.sql` y se ejecutan desde Python mediante DuckDB.

La consulta realiza las siguientes etapas:

1. Convierte identificadores, fechas y la variable objetivo a tipos adecuados.
2. Excluye registros con datos esenciales inválidos y citas cuya fecha es anterior a la fecha de programación.
3. Agrupa las citas por paciente y fecha para evitar que las citas del mismo día se incorporen mutuamente al historial.
4. Calcula las variables históricas mediante funciones de ventana, como `LAG()` y `SUM() OVER()`, además de ventanas temporales para medir la actividad.
5. Asocia las métricas calculadas con cada cita y conserva `no_show` como variable objetivo.

Las features utilizan información de fechas anteriores a la cita evaluada, evitando incorporar el resultado de esa misma cita en sus propios predictores.

## 5. Manejo de valores nulos

Cuando un paciente no tiene citas anteriores, `frequency` y las métricas de actividad toman el valor cero cuando corresponde.

En cambio, `recency_days` y `historical_no_show_rate` permanecen nulas si no existe historial previo suficiente para calcularlas. Esto evita interpretar la ausencia de información como una recencia de cero días o una tasa de inasistencia del 0 %.

## 6. Validación

La consulta generó **110.522 registros**, sin identificadores de cita duplicados. Se excluyeron cinco registros por inconsistencias temporales.

Los controles verificaron que:

* Las citas sin historial tienen recencia y tasa histórica nulas.
* Las citas con historial tienen ambas métricas disponibles.
* La tasa histórica se encuentra entre 0 y 1.
* Las métricas de actividad no presentan valores negativos.

Estos controles validan aspectos de integridad y consistencia de las features, pero no demuestran por sí mismos su capacidad predictiva.

## 7. Estructura del proyecto

```text
patient-attendance-feature-engineering/
├── data/
│   └── KaggleV2-May-2016.csv  # Archivo local, no incluido en Git
├── notebooks/
│   ├── 01_Exploratory.ipynb
│   └── 02_feature_engineering.ipynb
├── sql/
│   └── feature_engineering.sql
├── README.md
└── requirements.txt
```

El archivo CSV debe descargarse desde la fuente original de Kaggle y guardarse localmente en `data/`. No se incluye en el repositorio.

## 8. Ejecución

1. Descargar el dataset desde la fuente indicada.
2. Guardar `KaggleV2-May-2016.csv` en la carpeta local `data/`.
3. Instalar las dependencias listadas en `requirements.txt`.
4. Ejecutar los notebooks en orden: primero `01_Exploratory.ipynb` y después `02_feature_engineering.ipynb`.

## 9. Limitaciones

El dataset cubre un período histórico acotado y no contiene variables económicas. Algunos pacientes carecen de historial suficiente para calcular métricas históricas.

El proyecto se limita a la ingeniería de features para analizar inasistencias a citas médicas. No predice el abandono de tratamientos clínicos ni incluye todavía una evaluación de un modelo predictivo.

