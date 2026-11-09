defmodule Archivo do
  @moduledoc """
  Lectura genérica de archivos de texto.
  """

  @doc """
  Lee `ruta` línea por línea y aplica `parser` a cada una.
  """
  def leer(ruta, parser) do
    try do
      {registros, rechazados} =
        ruta
        |> File.stream!([], :line)
        |> Enum.reduce({[], 0}, fn linea, {acumulados, rechazados} ->
          case parser.(linea) do
            {:ok, registro} -> {[registro | acumulados], rechazados}
            {:error, _motivo} -> {acumulados, rechazados + 1}
            :vacia -> {acumulados, rechazados}
          end
        end)

      {:ok, %{registros: Enum.reverse(registros), rechazados: rechazados}}
    rescue
      error in File.Error -> {:error, error.reason}
    end
  end
end
