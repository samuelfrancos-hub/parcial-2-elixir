Code.require_file("carga.exs", __DIR__)
Code.require_file("calculo.exs", __DIR__)

defmodule Observatorio do
  @moduledoc """
  Orquesta la generación del reporte local del Punto 1:
  carga concurrente, cálculo por ciudad, presentación y guardado.
  """

  @doc """
  Genera el reporte, lo muestra en consola y lo guarda en
  `resources/reporte_sismos.txt`.

  Si falla la lectura de algún archivo de entrada, informa cuál falló y
  conserva el reporte anterior.
  """
  def generar_reporte do
    case Coordinador.cargar_datos() do
      {:ok, datos} ->
        resumenes = Calculo.resumir_ciudades(datos.ciudades, datos.movimientos)
        reporte = formatear_reporte(resumenes, datos.rechazados)

        IO.puts(reporte)
        guardar_reporte(reporte)

      {:error, fallos} ->
        IO.puts("No se pudo generar el reporte. Se conserva el reporte anterior.")
        Enum.each(fallos, fn fallo -> IO.puts(Coordinador.mensaje_error(fallo)) end)
    end

    :ok
  end

  # ---------- Formato del reporte ----------

  def formatear_reporte(resumenes, rechazados) do
    lineas =
      [
        "============================================================",
        "REPORTE DE MOVIMIENTOS SÍSMICOS POR CIUDAD",
        "============================================================",
        ""
      ] ++
        Enum.flat_map(resumenes, &formatear_ciudad/1) ++
        formatear_rechazados(rechazados)

    Enum.join(lineas, "\n")
  end

  def formatear_ciudad(resumen) do
    ciudad = resumen.ciudad

    [
      "Ciudad: #{ciudad.nombre} (#{ciudad.id})",
      "Número de habitantes: #{ciudad.habitantes}",
      "Movimientos:"
    ] ++
      formatear_movimientos(resumen.movimientos) ++
      [
        "Cantidad total de movimientos: #{resumen.total}",
        "Movimiento de mayor magnitud: #{formatear_mayor(resumen.mayor_magnitud)}",
        "Profundidad promedio: #{formatear_promedio(resumen.profundidad_promedio)}",
        ""
      ]
  end

  defp formatear_movimientos([]), do: ["  Sin movimientos registrados"]

  defp formatear_movimientos(movimientos) do
    Enum.map(movimientos, fn movimiento ->
      "  #{movimiento.codigo} | #{movimiento.hora_inicio} - #{movimiento.hora_final} | " <>
        "Magnitud: #{movimiento.magnitud} | Profundidad: #{movimiento.profundidad} km"
    end)
  end

  defp formatear_mayor({codigo, magnitud}), do: "#{codigo} · #{magnitud}"
  defp formatear_mayor("No aplica"), do: "No aplica"

  defp formatear_promedio("No aplica"), do: "No aplica"
  defp formatear_promedio(promedio), do: "#{promedio} km"

  defp formatear_rechazados(rechazados) do
    total = rechazados.ciudades + rechazados.movimientos

    [
      "Registros rechazados:",
      "  Ciudades: #{rechazados.ciudades}",
      "  Movimientos: #{rechazados.movimientos}",
      "Total de registros rechazados: #{total}"
    ]
  end

  # ---------- Guardado ----------

  defp guardar_reporte(reporte) do
    case Persistencia.guardar_reporte(reporte) do
      :ok ->
        IO.puts("\nReporte guardado en #{Persistencia.ruta_reporte()}")

      {:error, razon} ->
        IO.puts(
          "\nNo se pudo guardar el reporte en #{Persistencia.ruta_reporte()}: " <>
            "#{:file.format_error(razon)}"
        )
    end
  end
end
