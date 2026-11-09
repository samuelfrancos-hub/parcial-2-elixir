Code.require_file("txt.exs", __DIR__)
Code.require_file("registros.exs", __DIR__)

defmodule Persistencia do
  @moduledoc """
  Rutas y operaciones de acceso a los archivos del Punto 1.
  """

  @ruta_ciudades Path.join(__DIR__, "resources/ciudades.txt")
  @ruta_movimientos Path.join(__DIR__, "resources/movimientos.txt")
  @ruta_reporte Path.join(__DIR__, "resources/reporte_sismos.txt")

  def ruta_ciudades, do: @ruta_ciudades
  def ruta_movimientos, do: @ruta_movimientos
  def ruta_reporte, do: @ruta_reporte

  def cargar_ciudades, do: cargar_ciudades(@ruta_ciudades)

  def cargar_ciudades(ruta) do
    Archivo.leer(ruta, &Registros.parsear_ciudad/1)
  end

  def cargar_movimientos, do: cargar_movimientos(@ruta_movimientos)

  def cargar_movimientos(ruta) do
    Archivo.leer(ruta, &Registros.parsear_movimiento/1)
  end

  def guardar_reporte(contenido), do: guardar_reporte(contenido, @ruta_reporte)

  def guardar_reporte(contenido, ruta) do
    File.write(ruta, contenido <> "\n")
  end
end
