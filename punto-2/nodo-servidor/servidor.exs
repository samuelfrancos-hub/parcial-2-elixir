Code.require_file("reporte.exs", __DIR__)

defmodule Servidor do
  @moduledoc """
  Nodo servidor. Proceso registrado como :servicio_sismos.

  Recibe:  {destino, {:reporte_ciudad, id_ciudad}} | {destino, :reporte_general} | {destino, :fin}
  Responde a destino con: {:reporte, texto}  |  :fin
  """

  @espera_ms 10_000

  def iniciar do
    Process.register(self(), :servicio_sismos)
    IO.puts("Servidor listo en #{node()} (proceso :servicio_sismos)")
    esperar()
  end

  # Un solo proceso atiende de a una solicitud: las respuestas salen en el
  # mismo orden en que llegaron.
  defp esperar do
    receive do
      {destino, {:reporte_ciudad, id_ciudad}} ->
        send(destino, {:reporte, reporte_ciudad(id_ciudad)})
        esperar()

      {destino, :reporte_general} ->
        send(destino, {:reporte, reporte_general()})
        esperar()

      {destino, :fin} ->
        send(destino, :fin)
        esperar()

      otro ->
        IO.puts("Mensaje no reconocido: #{inspect(otro)}")
        esperar()
    end
  end

  # ---------- Consultas (reutilizan validaciones y cálculos del punto 1) ----------

  defp reporte_ciudad(id_ciudad) do
    con_datos(fn datos ->
      case Enum.find(datos.ciudades, &(&1.id == id_ciudad)) do
        nil ->
          "La ciudad no está registrada"

        ciudad ->
          [resumen] = Calculo.resumir_ciudades([ciudad], datos.movimientos)

          resumen
          |> Observatorio.formatear_ciudad()
          |> Enum.join("\n")
      end
    end)
  end

  defp reporte_general do
    con_datos(fn datos ->
      datos.ciudades
      |> Calculo.resumir_ciudades(datos.movimientos)
      |> Observatorio.formatear_reporte(datos.rechazados)
    end)
  end

  defp con_datos(funcion) do
    case leer_archivos() do
      {:ok, datos} -> funcion.(datos)
      {:error, fallos} -> Enum.map_join(fallos, "\n", &Coordinador.mensaje_error/1)
    end
  end

  # Lee las versiones ACTUALES de ambos archivos con dos Task concurrentes.
  # Ambos Task se inician antes de esperar cualquiera de los dos.
  defp leer_archivos do
    ruta_c = Persistencia.ruta_ciudades()
    ruta_m = Persistencia.ruta_movimientos()

    tarea_c = Task.async(fn -> Persistencia.cargar_ciudades() end)
    tarea_m = Task.async(fn -> Persistencia.cargar_movimientos() end)

    try do
      resultados = %{
        ciudades: {ruta_c, Task.await(tarea_c, @espera_ms)},
        movimientos: {ruta_m, Task.await(tarea_m, @espera_ms)}
      }

      Coordinador.clasificar_resultados(resultados)
    catch
      :exit, _ -> {:error, [{:ciudades, ruta_c, :timeout}, {:movimientos, ruta_m, :timeout}]}
    end
  end
end

Servidor.iniciar()
