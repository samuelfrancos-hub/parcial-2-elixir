Code.require_file("registros.exs", __DIR__)

defmodule Lector do
  @moduledoc """
  Lectura de UN archivo: lee, parsea cada línea con Registros y cuenta rechazados.

  Retorna:
    * {:ok, %{registros: [struct], rechazados: n}}
    * {:error, razon}   (razon = átomo de File.read/1, p. ej. :enoent)
  """

  def leer_ciudades(ruta), do: leer(ruta, &Registros.parsear_ciudad/1)
  def leer_movimientos(ruta), do: leer(ruta, &Registros.parsear_movimiento/1)

  defp leer(ruta, parser) do
    case File.read(ruta) do
      {:ok, contenido} ->
        {registros, rechazados} =
          contenido
          |> String.split(~r/\R/)
          |> clasificar(parser, [], 0)

        {:ok, %{registros: registros, rechazados: rechazados}}

      {:error, razon} ->
        {:error, razon}
    end
  end

  # Recorrido recursivo: conserva el orden del archivo y cuenta rechazados.
  # :vacia se ignora (no suma a rechazados).
  defp clasificar([], _parser, acc, rechazados), do: {Enum.reverse(acc), rechazados}

  defp clasificar([linea | resto], parser, acc, rechazados) do
    case parser.(linea) do
      {:ok, registro} -> clasificar(resto, parser, [registro | acc], rechazados)
      {:error, _motivo} -> clasificar(resto, parser, acc, rechazados + 1)
      :vacia -> clasificar(resto, parser, acc, rechazados)
    end
  end
end

defmodule Coordinador do
  @moduledoc "Lanza ambas lecturas en paralelo con Task y consolida los resultados."

  @timeout 10_000

  @doc """
  Retorna:
    * {:ok, %{ciudades: [...], movimientos: [...],
              rechazados: %{ciudades: n, movimientos: n}}}
    * {:error, [{:ciudades | :movimientos, ruta, razon}, ...]}
  """
  def cargar_datos(ruta_ciudades, ruta_movimientos) do
    # 1) Se inician AMBOS Task antes de esperar cualquier resultado
    tarea_ciudades =
      Task.async(fn -> {:ciudades, ruta_ciudades, Lector.leer_ciudades(ruta_ciudades)} end)

    tarea_movimientos =
      Task.async(fn ->
        {:movimientos, ruta_movimientos, Lector.leer_movimientos(ruta_movimientos)}
      end)

    # 2) Recién ahora se espera (ya corren en paralelo)
    resultados = [
      Task.await(tarea_ciudades, @timeout),
      Task.await(tarea_movimientos, @timeout)
    ]

    # 3) Solo se continúa si ambos fueron exitosos
    case Enum.filter(resultados, fn {_archivo, _ruta, res} -> match?({:error, _}, res) end) do
      [] -> {:ok, consolidar(resultados)}
      fallos -> {:error, Enum.map(fallos, fn {a, ruta, {:error, r}} -> {a, ruta, r} end)}
    end
  end

  def mensaje_error({archivo, ruta, razon}) do
    "No se pudo leer el archivo de #{archivo} (#{ruta}): #{:file.format_error(razon)}"
  end

  # Un movimiento cuyo idCiudad no está en el catálogo se rechaza.
  # Solo se puede decidir aquí, cuando ya se tienen ambos archivos.
  defp consolidar(resultados) do
    {:ok, ciu} = resultados |> List.keyfind(:ciudades, 0) |> elem(2)
    {:ok, mov} = resultados |> List.keyfind(:movimientos, 0) |> elem(2)

    ids = MapSet.new(ciu.registros, & &1.id)
    {validos, huerfanos} = Enum.split_with(mov.registros, &MapSet.member?(ids, &1.id_ciudad))

    %{
      ciudades: ciu.registros,
      movimientos: validos,
      rechazados: %{
        ciudades: ciu.rechazados,
        movimientos: mov.rechazados + length(huerfanos)
      }
    }
  end
end

# Prueba rápida (desde punto-1/): elixir carga.exs
if System.argv() == [] and Path.basename(__ENV__.file) == "carga.exs" and
     File.exists?("resources/ciudades.txt") do
  case Coordinador.cargar_datos("resources/ciudades.txt", "resources/movimientos.txt") do
    {:ok, datos} -> IO.inspect(datos, pretty: true)
    {:error, fallos} -> Enum.each(fallos, &IO.puts(Coordinador.mensaje_error(&1)))
  end
end
