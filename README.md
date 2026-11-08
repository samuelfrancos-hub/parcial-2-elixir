# Parcial II – Programación 3: Observatorio Sismológico (Elixir)

Universidad del Quindío · Ingeniería de Sistemas y Computación

Aplicación en Elixir que genera un reporte de sismos por ciudad (Punto 1) y permite consultarlo desde otro nodo (Punto 2).

## Estructura del repositorio

```
parcial-2-elixir/
├── README.md
├── punto-1/
│   ├── main.exs          # punto de entrada
│   ├── archivo.exs       # lectura genérica de archivos con parser por línea
│   ├── persistencia.exs  # rutas y acceso a los archivos del punto 1
│   ├── registros.exs     # structs Ciudad y MovimientoSismico, parseo y validación de una línea
│   ├── carga.exs         # coordinación concurrente con spawn/send/receive y cruce de catálogos
│   ├── calculo.exs       # estadísticas por ciudad (un solo recorrido recursivo)
│   ├── reporte.exs       # formato del reporte, guardado y orquestación
│   └── resources/
│       ├── ciudades.txt
│       └── movimientos.txt   # (reporte_sismos.txt se genera aquí)
└── punto-2/
    ├── nodo-cliente/
    │   └── cliente.exs
    └── nodo-servidor/
        ├── servidor.exs
        ├── archivo.exs       # copias de los módulos del punto 1
        ├── persistencia.exs
        ├── registros.exs
        ├── carga.exs
        ├── calculo.exs
        ├── reporte.exs
        └── resources/
            ├── ciudades.txt
            └── movimientos.txt
```

Requisito: Elixir instalado (`elixir --version`). Cada comando indica la carpeta desde la que se ejecuta.

## Datos de prueba

`resources/ciudades.txt` (formato `idCiudad@nombre@numeroHabitantes`, sin encabezado):

```
C01@Armenia@304314
C02@Calarcá@78684
C03@Circasia@30941
```

`resources/movimientos.txt` (formato `código@idCiudad@horaInicio@horaFinal@magnitud@profundidad`, sin encabezado):

```
S001@C01@08:15:02@08:15:18@3.4@18.0
S002@C02@09:30:10@09:30:29@4.1@25.0
S003@C01@11:42:00@11:42:12@2.8@10.0
```

Con estos datos: Armenia → 2 movimientos, mayor `S001 · 3.4`, promedio `14.00 km`; Calarcá → 1 movimiento, mayor `S002 · 4.1`, promedio `25.00 km`; Circasia → `Sin movimientos registrados`, total 0, `No aplica` en magnitud máxima y profundidad promedio.

Para probar registros rechazados, agregue a `movimientos.txt` líneas como `S004@C01@25:00:00@08:15:18@3.4@5.0` (hora inválida), `S005@C01@08:00:00@08:00:10@abc@5.0` (magnitud inválida), `S006@C01@08:00:00@08:00:10@3.0@-1` (profundidad negativa) o `S007@C99@08:00:00@08:00:10@3.0@5.0` (ciudad inexistente). Las líneas vacías se ignoran y no cuentan como rechazadas.

## Punto 1 – Reporte local

Desde la carpeta `punto-1/`:

```
elixir main.exs
```

- **Entrada:** `punto-1/resources/ciudades.txt` y `punto-1/resources/movimientos.txt`.
- **Salida:** el reporte se imprime en consola y se guarda en `punto-1/resources/reporte_sismos.txt`, reemplazando el contenido anterior en cada generación exitosa.
- Si no se puede leer alguno de los archivos de entrada, se indica cuál falló y se conserva el reporte anterior.
- Si falla la escritura del reporte, se informa el error en consola.

## Punto 2 – Consulta entre nodos

Se usan dos terminales. Nodos: `servidor` y `cliente` (nombres cortos, `--sname`), ambos con la misma cookie: `parcial`. Primero se inicia el servidor y después el cliente.

**Terminal 1 – servidor.** Desde `punto-2/nodo-servidor/`:

```
elixir --sname servidor --cookie parcial servidor.exs
```

Debe imprimir `Servidor listo en servidor@<hostname> (proceso :servicio_sismos)` y quedar esperando solicitudes. El servidor lee `resources/ciudades.txt` y `resources/movimientos.txt` de su propia carpeta en cada consulta.

**Terminal 2 – cliente.** Desde `punto-2/nodo-cliente/`:

```
elixir --sname cliente --cookie parcial cliente.exs
```

El cliente asume que el servidor es `servidor@<mismo hostname>`. Si está en otro equipo o el nombre es distinto, se indica como argumento:

```
elixir --sname cliente --cookie parcial cliente.exs servidor@NOMBRE_DEL_EQUIPO
```

(`hostname` muestra el nombre del equipo.) Si la conexión falla (`Node.connect/1`), el cliente informa el error en consola y termina.

### Identificadores usados en las pruebas del cliente

| Solicitud | Identificador | Resultado esperado |
|---|---|---|
| 1. Ciudad con movimientos | `C01` (Armenia) | 2 movimientos, mayor `S001 · 3.4`, promedio `14.00 km` |
| 2. Ciudad sin movimientos | `C03` (Circasia) | `Sin movimientos registrados`, total 0, `No aplica` / `No aplica` |
| 3. Ciudad inexistente | `C99` | `La ciudad no está registrada` |
| 4. Reporte general | `:reporte_general` | todas las ciudades y conteo de rechazados por archivo |
| 5. Fin | `:fin` | confirmación `:fin` |

### Verificación de que el servidor sigue atendiendo

Con el servidor aún en ejecución en la Terminal 1, ejecute el mismo comando del cliente por segunda vez en la Terminal 2. Cada ejecución debe mostrar las cuatro respuestas en orden, seguidas de la confirmación `:fin`, y terminar. Para detener el servidor, presione `Ctrl+C` dos veces en la Terminal 1.

### Protocolo

- Solicitudes (cliente → proceso `:servicio_sismos`): `{destino_respuesta, {:reporte_ciudad, idCiudad}}`, `{destino_respuesta, :reporte_general}` y `{destino_respuesta, :fin}`, con `destino_respuesta = {:servicio_respuesta, nodo_cliente}`.
- Respuestas (servidor → cliente): `{:reporte, texto}` para cada consulta y `:fin` como confirmación, en el mismo orden en que llegaron las solicitudes.
- Para cada consulta el servidor lee las versiones actuales de ambos archivos con dos `Task` concurrentes y reutiliza las validaciones y cálculos del Punto 1. Si un archivo no puede leerse, responde indicando cuál y sigue atendiendo.

## Decisiones de diseño

- La lectura concurrente de los dos archivos usa `spawn`, `send` y `receive`; el coordinador inicia ambos trabajadores antes de esperar sus resultados y los recibe en cualquier orden.
- Las estadísticas por ciudad (cantidad, mayor magnitud y suma de profundidades) se calculan con una única recursión explícita sobre los movimientos.
- Responsabilidades separadas: `archivo.exs` (lectura genérica con parser), `persistencia.exs` (rutas y acceso a archivos), `registros.exs` (parseo y validación), `carga.exs` (coordinación de procesos y cruce), `calculo.exs` (estadísticas) y `reporte.exs` (formato y guardado).

## Reflexión sobre el uso de inteligencia artificial



1. **Herramientas y agentes:** _qué asistentes se usaron y en qué tareas._
2. **Caso decisivo:** _una interacción concreta, la respuesta obtenida y cómo se verificó o adaptó._
3. **Idea diferente de la clase:** _una sugerencia distinta de las vistas en clase, su aporte, si se implementó y lo aprendido._
4. **Conclusiones:** _qué se comprende por sí solos, qué cuesta todavía y qué se cambiaría en un siguiente proyecto._
