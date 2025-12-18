# Computación en la Nube – Práctica 7

## 1. REQUISITOS FORMALES DE LA MEMORIA

### 1.1. Formato del documento

La memoria debe cumplir estrictamente con los siguientes requisitos de formato:

| Elemento                | Especificación                                            |
| ----------------------- | --------------------------------------------------------- |
| Tipo de letra (cuerpo)  | Times New Roman, 12 pt                                    |
| Tipo de letra (títulos) | Arial, negrita (14 pt H1, 13 pt H2, 12 pt H3)             |
| Interlineado            | 1,5 líneas                                                |
| Márgenes                | Superior, inferior y derecho: 2,5 cm; Izquierdo: 3 cm     |
| Alineación del texto    | Justificado                                               |
| Numeración de páginas   | Centrada en el pie de página, formato "Página X de Y"     |
| Encabezado              | Nombre de la asignatura y práctica, alineado a la derecha |
| Tamaño del papel        | A4 (210 x 297 mm)                                         |
| Formato de entrega      | PDF (obligatorio)                                         |
| Nombre del archivo      | P2_Apellido1_Apellido2_Nombre.pdf                         |

### 1.2. Figuras y tablas

Todas las figuras y tablas deben cumplir las siguientes normas:

* Las figuras deben estar numeradas correlativamente (Figura 1, Figura 2, etc.) y llevar un pie de figura descriptivo centrado debajo de la imagen.
* Las tablas deben estar numeradas correlativamente (Tabla 1, Tabla 2, etc.) y llevar un título centrado encima de la tabla.
* Todas las figuras y tablas deben ser referenciadas en el texto.
* Las capturas de pantalla deben ser legibles y de buena calidad.
* Se recomienda usar imágenes con resolución mínima de 150 ppp.

### 1.3. Código fuente

El código fuente incluido en la memoria debe seguir estas directrices:

* Utilizar fuente monoespaciada: Consolas o Courier New, 10 pt.
* Incluir el código en recuadros o con fondo gris claro (#F5F5F5) para diferenciarlo del texto.
* Añadir comentarios explicativos en el código cuando sea necesario.
* Si el código es extenso, incluirlo como anexo al final del documento. En **TODOS** los casos se ha de incluir la totalidad del código en la memoria.

## 2. ESTRUCTURA OBLIGATORIA DE LA MEMORIA

La memoria debe contener obligatoriamente los siguientes apartados, en el orden indicado:

### 2.1. Portada

Debe incluir: nombre de la universidad, escuela, titulación, asignatura, curso académico, título de la práctica, nombre completo del estudiante y fecha de entrega.

### 2.2. Índice de contenidos

Índice automático con numeración de páginas. Se recomienda incluir hasta 3 niveles de profundidad.

### 2.3. Introducción

Breve descripción del objetivo de la práctica y contextualización de los servicios AWS utilizados (S3, Kinesis, AWS Glue).

### 2.4. Desarrollo de las actividades

Este es el apartado principal de la memoria. Se debe documentar cada actividad de forma detallada:

#### 2.4.1. Configuración del bucket S3

Documentar la creación del bucket y la estructura de carpetas (raw, processed, config). Incluir capturas de pantalla de la consola AWS y justificar las decisiones de configuración tomadas.

#### 2.4.2. Implementación del productor de datos

Incluir el código completo del productor con comentarios. Explicar el tipo de datos generados (logs, métricas o transacciones) y la frecuencia de envío al Kinesis Data Stream.

#### 2.4.3. Configuración del consumidor (Kinesis Firehose)

Documentar la configuración de Firehose, incluyendo las transformaciones aplicadas (filtrado o enriquecimiento) y la configuración del destino en S3.

#### 2.4.4. Configuración de AWS Glue

Describir la configuración del crawler, el esquema generado en el Catálogo de Datos y el trabajo ETL implementado.

### 2.5. Diagrama del flujo de datos

Incluir un diagrama de arquitectura que muestre el flujo completo de datos desde el productor hasta el almacenamiento final en S3. Se recomienda usar herramientas como draw.io, Lucidchart o AWS Architecture Icons.

### 2.6. Presupuesto y estimación de costes

Detallar los costes estimados de cada servicio AWS utilizado. Incluir una tabla con el desglose de costes y el total estimado mensual y anual en un supuesto de uso real con los datos aportados y los supuestos. Utilizar la calculadora de precios de AWS como referencia, detallando tanto lo que se asume como la forma en que se llega al precio.

### 2.7. Conclusiones

Reflexión sobre los conocimientos adquiridos, dificultades encontradas y posibles mejoras o extensiones del trabajo realizado.

### 2.8. Referencias y bibliografía

Listado de todas las fuentes consultadas (documentación oficial de AWS, tutoriales, artículos, etc.) en formato APA.

### 2.9. Anexos

Código fuente completo, configuraciones JSON/YAML extensas, capturas adicionales u otro material complementario. Identificación de si se ha realizado el uso de IA y cómo.

## 3. CRITERIOS DE EVALUACIÓN

La memoria se evaluará sobre un total de 10 puntos, distribuidos de la siguiente forma:

| Criterio           | Puntos | Peso |
| ------------------ | ------ | ---- |
| Entrega de memoria | 10     | 100% |
| **TOTAL**          | 10     | 100% |

Teniendo en cuenta que la replicación del mismo tipo de datos o esquema de datos al entregado, así como cualquier variación sobre él, implica el suspenso automático de la práctica. Asimismo, para poder aprobarla es requisito y su incumplimiento implica suspenso:

1. Haber realizado la correcta ejecución de la práctica en AWS.
2. Haberlo hecho en su cuenta de AWS de forma individual y autónoma.
3. Que la práctica esté correctamente documentada y sea reproducible.
4. Tener todos los apartados evaluables entregados de forma adecuada.

### 3.1. Desglose de la evaluación de la memoria (10 puntos)

| Aspecto evaluado                                       | Puntos | Peso |
| ------------------------------------------------------ | ------ | ---- |
| Presentación y formato (cumplimiento de requisitos)    | 3      | 30%  |
| Descripción de los pasos seguidos (claridad y detalle) | 4      | 40%  |
| Código y configuraciones de recursos                   | 1      | 10%  |
| Diagrama del flujo de datos                            | 1      | 10%  |
| Presupuesto y estimación de gasto                      | 1      | 10%  |

## 4. DESCRIPCIÓN DE LAS ACTIVIDADES

El objetivo de esta práctica es aprender a gestionar la ingesta y procesamiento de datos a gran escala en AWS, utilizando servicios como S3, Kinesis y AWS Glue.

### 4.1. Actividades obligatorias

1. Configurar un bucket S3 con la estructura de carpetas adecuada para almacenar datos sin procesar, datos procesados, scripts y configuraciones.
2. Implementar un productor de datos que genere registros simulados (logs, métricas o transacciones) y los envíe a un Kinesis Data Stream.
3. Configurar un consumidor usando Kinesis Firehose que recoja los datos del stream, realice una transformación básica (filtrado o enriquecimiento) y almacene los resultados en el bucket S3 en la carpeta de datos procesados.
4. Utilizar AWS Glue para crear un crawler que analice los datos en S3, definir un esquema en el Catálogo de Datos y crear y ejecutar un trabajo ETL simple.

## 5. RECOMENDACIONES FINALES

* Revisar la fecha de entrega de la memoria en el Moodle.
* Revisar la memoria antes de la entrega.
* Revisar la ortografía y gramática del documento.
* Asegurarse de que todas las figuras y tablas sean legibles.
* Incluir capturas de pantalla relevantes que demuestren la correcta realización de cada paso.
* El código debe estar correctamente formateado e indentado.
* Verificar que el archivo PDF se abre correctamente y que todas las páginas son visibles.
* Revisar que la entrega se realice en la asignatura y práctica correcta.
* Eliminar los recursos de AWS al finalizar la práctica para evitar costes adicionales.
