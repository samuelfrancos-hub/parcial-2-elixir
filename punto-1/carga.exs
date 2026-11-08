Code.require_file("persistencia.exs", __DIR__)

defmodule Coordinador do
  @moduledoc """
  Coordina dos procesos trabajadores con spawn/send/receive.

  El coordinador inicia ambos trabajadores antes de esperar, recibe sus
  mensajes en cualquier orden y solo consolida los datos si ambos archivos
  se leyeron correctamente.
  """

  @timeout 10_000

  @doc """
  Carga los archivos por defecto definidos en `Persistencia`.
  """
  def cargar_datos do
    cargar_datos(Persistencia.ruta_ciudades(), Persistencia.ruta_movimientos())
  end

  @doc """
  Carga los archivos indicados
  """
  def cargar_datos(ruta_ciudades, ruta_movimientos) do
    coordinador = self()
    ref_ciudades = make_ref()
    ref_movimientos = make_ref()

    esperados = %{
      ref_ciudades => {:ciudades, ruta_ciudades},
      ref_movimientos => {:movimientos, ruta_movimientos}
    }

    # 1) Se lanzan AMBOS trabajadores antes de recibir cualquier resultado.
    lanzar(coordinador, ref_ciudades, :ciudades, ruta_ciudades, &Persistencia.cargar_ciudades/1)
    lanzar(coordinador, ref_movimientos, :movimientos, ruta_movimientos, &Persistencia.cargar_movimientos/1)

    # 2) El coordinador acepta las respuestas en cualquier orden.
    case esperar(esperados, %{}) do
      {:ok, resultados} ->
        clasificar_resultados(resultados)

      {:error, pendientes} ->
        {:error,
        Enum.map(pendientes, fn {_ref, {archivo, ruta}} -> {archivo, ruta, :timeout} end)}
    end
  end

  def mensaje_error({archivo, ruta, :timeout}) do
    "No se pudo completar la lectura del archivo de #{archivo} (#{ruta}): tiempo de espera agotado"
  end

  def mensaje_error({archivo, ruta, razon}) do
    "No se pudo leer el archivo de #{archivo} (#{ruta}): #{:file.format_error(razon)}"
  end

  # ---------- Procesos trabajadores ----------

  defp lanzar(coordinador, ref, archivo, ruta, cargador) do
    spawn(fn ->
      resultado = cargador.(ruta)
      send(coordinador, {:lectura, ref, archivo, ruta, resultado})
    end)
  end

  # ---------- Recepción de resultados ----------

  defp esperar(esperados, resultados) when map_size(esperados) == 0 do
    {:ok, resultados}
  end

  defp esperar(esperados, resultados) do
    receive do
      {:lectura, ref, _archivo, _ruta, resultado} ->
        case Map.pop(esperados, ref) do
          {nil, _} ->
            # Mensaje repetido o de otro coordinador: se ignora.
            esperar(esperados, resultados)

          {esperado, restantes} ->
            {archivo, ruta} = esperado
            esperar(restantes, Map.put(resultados, archivo, {ruta, resultado}))
        end
    after
      @timeout -> {:error, esperados}
    end
  end

  # ---------- Consolidación ----------

  defp clasificar_resultados(resultados) do
    fallos =
      for archivo <- [:ciudades, :movimientos],
          {ruta, {:error, razon}} <- [Map.fetch!(resultados, archivo)],
          do: {archivo, ruta, razon}

    case fallos do
      [] -> {:ok, consolidar(resultados)}
      _ -> {:error, fallos}
    end
  end

  # Un movimiento cuyo idCiudad no está en el catálogo se rechaza.
  # Solo se puede decidir aquí, cuando ya se tienen ambos archivos.
  defp consolidar(resultados) do
    {_ruta_ciudades, {:ok, ciu}} = Map.fetch!(resultados, :ciudades)
    {_ruta_movimientos, {:ok, mov}} = Map.fetch!(resultados, :movimientos)

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
