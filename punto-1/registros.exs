defmodule Ciudad do
  @moduledoc "Ciudad válida del catálogo del observatorio."

  @enforce_keys [:id, :nombre, :habitantes]
  defstruct [:id, :nombre, :habitantes]
end

defmodule MovimientoSismico do
  @moduledoc "Movimiento sísmico validado y asociado a una ciudad."

  @enforce_keys [:codigo, :id_ciudad, :hora_inicio, :hora_final, :magnitud, :profundidad]
  defstruct [:codigo, :id_ciudad, :hora_inicio, :hora_final, :magnitud, :profundidad]
end

defmodule Registros do
  @moduledoc """
  Parseo y validación de una línea de los archivos de entrada.

  Cada función retorna:

    * `:vacia` cuando la línea está vacía o solo contiene espacios.
    * `{:ok, struct}` cuando la línea es válida.
    * `{:error, motivo}` cuando la línea debe contarse como rechazada.
  """

  @doc """
  Parsea una línea con formato `idCiudad@nombre@numeroHabitantes`.
  """
  def parsear_ciudad(linea) do
    case campos(linea) do
      :vacia ->
        :vacia

      [id, nombre, habitantes] ->
        with :ok <- requerido(id, :id),
            :ok <- requerido(nombre, :nombre),
            {:ok, habitantes} <- entero_positivo(habitantes) do
          {:ok, %Ciudad{id: id, nombre: nombre, habitantes: habitantes}}
        else
          {:error, motivo} -> {:error, motivo}
        end

      _ ->
        {:error, :numero_de_campos}
    end
  end

  @doc """
  Parsea una línea con formato
  `codigo@idCiudad@horaInicio@horaFinal@magnitud@profundidad`.

  La ciudad asociada se valida después, cuando ya se conoce el catálogo.
  """
  def parsear_movimiento(linea) do
    case campos(linea) do
      :vacia ->
        :vacia

      [codigo, id_ciudad, hora_inicio, hora_final, magnitud, profundidad] ->
        with :ok <- requerido(codigo, :codigo),
             :ok <- requerido(id_ciudad, :id_ciudad),
             :ok <- hora_valida(hora_inicio),
             :ok <- hora_valida(hora_final),
             {:ok, magnitud} <- decimal(magnitud),
             {:ok, profundidad} <- decimal_no_negativo(profundidad) do
          {:ok,
           %MovimientoSismico{
             codigo: codigo,
             id_ciudad: id_ciudad,
             hora_inicio: hora_inicio,
             hora_final: hora_final,
             magnitud: magnitud,
             profundidad: profundidad
           }}
        else
          {:error, motivo} -> {:error, motivo}
        end

      _ ->
        {:error, :numero_de_campos}
    end
  end

  # ---------- Utilidades de validación ----------

  defp campos(linea) do
    if String.trim(linea) == "" do
      :vacia
    else
      linea
      |> String.split("@", trim: false)
      |> Enum.map(&String.trim/1)
    end
  end

  defp requerido("", _campo), do: {:error, :campo_obligatorio_vacio}
  defp requerido(_valor, _campo), do: :ok

  # HH:MM:SS con horas 00-23, minutos 00-59 y segundos 00-59.
  defp hora_valida(hora) do
    case String.split(hora, ":") do
      [hh, mm, ss] ->
        with true <- String.length(hh) == 2,
             true <- String.length(mm) == 2,
             true <- String.length(ss) == 2,
             {h, ""} <- Integer.parse(hh),
             {m, ""} <- Integer.parse(mm),
             {s, ""} <- Integer.parse(ss),
             true <- h in 0..23,
             true <- m in 0..59,
             true <- s in 0..59 do
          :ok
        else
          _ -> {:error, :hora_invalida}
        end

      _ ->
        {:error, :hora_invalida}
    end
  end

  defp entero_positivo(valor) do
    case Integer.parse(valor) do
      {numero, ""} when numero > 0 -> {:ok, numero}
      _ -> {:error, :habitantes_invalidos}
    end
  end

  defp decimal(valor) do
    case Float.parse(valor) do
      {numero, ""} ->
        {:ok, numero}

      _ ->
        case Integer.parse(valor) do
          {numero, ""} -> {:ok, numero * 1.0}
          _ -> {:error, :numero_invalido}
        end
    end
  end

  defp decimal_no_negativo(valor) do
    case decimal(valor) do
      {:ok, numero} when numero >= 0.0 -> {:ok, numero}
      _ -> {:error, :numero_invalido}
    end
  end
end
