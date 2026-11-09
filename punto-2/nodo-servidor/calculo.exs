defmodule Calculo do
  @moduledoc """
  Cruce ciudades <-> movimientos y estadísticas por ciudad.

  Entrada: lista de %Ciudad{} y lista de %MovimientoSismico{} ya validados
  (los movimientos con idCiudad inexistente ya fueron rechazados en
  Coordinador.consolidar/1).

  Salida: una lista (mismo orden del catálogo, TODAS las ciudades) de mapas:

    %{ciudad: %Ciudad{},
      movimientos: [%MovimientoSismico{}],     # en el orden del archivo
      total: integer,
      mayor_magnitud: {codigo, magnitud} | "No aplica",
      suma_profundidad: float,
      profundidad_promedio: "14.00" | "No aplica"}
  """

  def resumir_ciudades(ciudades, movimientos) do
    # group_by conserva el orden relativo del archivo dentro de cada ciudad
    por_ciudad = Enum.group_by(movimientos, & &1.id_ciudad)

    Enum.map(ciudades, fn ciudad ->
      resumir(ciudad, Map.get(por_ciudad, ciudad.id, []))
    end)
  end

  defp resumir(ciudad, movimientos) do
    # UN solo recorrido recursivo calcula cantidad, mayor magnitud y suma
    %{cantidad: cantidad, mayor: mayor, suma: suma} =
      recorrer(movimientos, %{cantidad: 0, mayor: nil, suma: 0.0})

    %{
      ciudad: ciudad,
      movimientos: movimientos,
      total: cantidad,
      mayor_magnitud: texto_mayor(mayor),
      suma_profundidad: suma,
      profundidad_promedio: promedio(suma, cantidad)
    }
  end

  # ---------- Recursión explícita (un solo recorrido) ----------

  defp recorrer([], acumulado), do: acumulado

  defp recorrer([movimiento | resto], %{cantidad: n, mayor: mayor, suma: suma}) do
    recorrer(resto, %{
      cantidad: n + 1,
      mayor: mayor_entre(mayor, movimiento),
      suma: suma + movimiento.profundidad
    })
  end

  # Estricto (>): en empate se conserva el primero del archivo
  defp mayor_entre(nil, %{codigo: codigo, magnitud: magnitud}), do: {codigo, magnitud}

  defp mayor_entre({_codigo, mayor}, %{codigo: codigo, magnitud: magnitud})
       when magnitud > mayor,
       do: {codigo, magnitud}

  defp mayor_entre(actual, _movimiento), do: actual

  # ---------- Resultados finales ----------

  defp texto_mayor(nil), do: "No aplica"
  defp texto_mayor({codigo, magnitud}), do: {codigo, magnitud}

  defp promedio(_suma, 0), do: "No aplica"
  defp promedio(suma, cantidad), do: :erlang.float_to_binary(suma / cantidad, decimals: 2)
end
