defmodule Cliente do
  @moduledoc """
  Nodo cliente. Proceso registrado como :servicio_respuesta.
  Envía 5 solicitudes a :servicio_sismos y muestra las respuestas hasta recibir :fin.
  """

  @id_con_movimientos "C01"
  @id_sin_movimientos "C03"
  @id_inexistente "C99"

  @espera_ms 10_000

  # Uso: elixir --sname cliente --cookie parcial cliente.exs [nodo_servidor]
  # Sin argumento asume servidor@<mismo host>.
  def iniciar(args) do
    if Node.alive?() do
      servidor = nodo_servidor(args)
      Process.register(self(), :servicio_respuesta)

      case Node.connect(servidor) do
        true ->
          IO.puts("Conectado a #{servidor}")
          enviar_solicitudes(servidor)
          recibir(1)

        _fallo ->
          IO.puts(
            "Error: no se pudo conectar al nodo servidor #{servidor}. " <>
              "Verifique que esté iniciado, el nombre del nodo y la cookie."
          )
      end
    else
      IO.puts("Error: inicie el cliente con --sname y --cookie (ver README).")
    end
  end

  defp nodo_servidor([nombre | _]), do: String.to_atom(nombre)

  defp nodo_servidor([]) do
    [_nombre, host] = node() |> Atom.to_string() |> String.split("@")
    String.to_atom("servidor@" <> host)
  end

  defp enviar_solicitudes(servidor) do
    destino = {:servicio_respuesta, node()}

    [
      {:reporte_ciudad, @id_con_movimientos},
      {:reporte_ciudad, @id_sin_movimientos},
      {:reporte_ciudad, @id_inexistente},
      :reporte_general,
      :fin
    ]
    |> Enum.each(fn solicitud -> send({:servicio_sismos, servidor}, {destino, solicitud}) end)
  end

  defp recibir(n) do
    receive do
      {:reporte, texto} ->
        IO.puts("--- Respuesta #{n} ---")
        IO.puts(texto)
        recibir(n + 1)

      :fin ->
        IO.puts("--- Confirmación :fin recibida; fin de las respuestas ---")
    after
      @espera_ms -> IO.puts("Error: el servidor no respondió en #{div(@espera_ms, 1000)} s.")
    end
  end
end

Cliente.iniciar(System.argv())
