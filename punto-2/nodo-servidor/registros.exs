defmodule Ciudad do
  @moduledoc "Ciudad del catálogo (resources/ciudades.txt)."
  @enforce_keys [:id, :nombre, :habitantes]
  defstruct [:id, :nombre, :habitantes]
end

defmodule MovimientoSismico do
  @moduledoc "Movimiento sísmico (resources/movimientos.txt)."
  @enforce_keys [:codigo, :id_ciudad, :hora_inicio, :hora_final, :magnitud, :profundidad]
  defstruct [:codigo, :id_ciudad, :hora_inicio, :hora_final, :magnitud, :profundidad]
end

defmodule Registros do
  @moduledoc """
  Parseo y validación de UNA línea de cada archivo.

  Retorno de ambas funciones públicas:
    * {:ok, struct}       -> línea válida
    * {:error, motivo}    -> línea a contar como registro rechazado
    * :vacia              -> línea en blanco (se IGNORA, no se cuenta como rechazada)
  """

  # ---------- API pública ----------

  # Formato: idCiudad@nombre@numeroHabitantes
  def parsear_ciudad(linea) do
    case String.trim(linea) do
      "" ->
        :vacia

      limpia ->
        with {:ok, [id, nombre, hab]} <- separar(limpia, 3),
             :ok <- sin_vacios([id, nombre, hab]),
             {:ok, habitantes} <- entero_positivo(hab, :habitantes_invalido) do
          {:ok, %Ciudad{id: id, nombre: nombre, habitantes: habitantes}}
        end
    end
  end

  # Formato: código@idCiudad@horaInicio@horaFinal@magnitud@profundidad
  def parsear_movimiento(linea) do
    case String.trim(linea) do
      "" ->
        :vacia

      limpia ->
        with {:ok, [codigo, id_ciudad, h_ini, h_fin, mag, prof]} <- separar(limpia, 6),
             :ok <- sin_vacios([codigo, id_ciudad, h_ini, h_fin, mag, prof]),
             {:ok, hora_inicio} <- hora(h_ini, :hora_inicio_invalida),
             {:ok, hora_final} <- hora(h_fin, :hora_final_invalida),
             {:ok, magnitud} <- decimal(mag, :magnitud_invalida),
             {:ok, profundidad} <- profundidad(prof) do
          {:ok,
           %MovimientoSismico{
             codigo: codigo,
             id_ciudad: id_ciudad,
             hora_inicio: hora_inicio,
             hora_final: hora_final,
             magnitud: magnitud,
             profundidad: profundidad
           }}
        end
    end
  end

  # ---------- Validaciones privadas ----------

  # Exactamente n campos separados por @ (ni más ni menos)
  defp separar(linea, n) do
    campos = linea |> String.split("@") |> Enum.map(&String.trim/1)

    if length(campos) == n, do: {:ok, campos}, else: {:error, :formato_invalido}
  end

  defp sin_vacios(campos) do
    if Enum.any?(campos, &(&1 == "")), do: {:error, :campo_vacio}, else: :ok
  end

  # Entero estricto > 0: rechaza "12abc", "3.5", "-4", "0"
  defp entero_positivo(texto, motivo) do
    case Integer.parse(texto) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> {:error, motivo}
    end
  end

  # Decimal estricto: "3", "3.4", "-1.2". Rechaza "3.", ".5", "1e5", "abc"
  defp decimal(texto, motivo) do
    if Regex.match?(~r/^-?\d+(\.\d+)?$/, texto) do
      {numero, ""} = Float.parse(texto)
      {:ok, numero}
    else
      {:error, motivo}
    end
  end

  defp profundidad(texto) do
    case decimal(texto, :profundidad_invalida) do
      {:ok, p} when p >= 0 -> {:ok, p}
      {:ok, _} -> {:error, :profundidad_negativa}
      error -> error
    end
  end

  # HH:MM:SS estricto (dos dígitos cada uno) y hora real del día (00:00:00–23:59:59)
  defp hora(texto, motivo) do
    with true <- Regex.match?(~r/^\d{2}:\d{2}:\d{2}$/, texto),
         {:ok, time} <- Time.from_iso8601(texto) do
      {:ok, time}
    else
      _ -> {:error, motivo}
    end
  end
end
