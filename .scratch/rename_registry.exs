files = Path.wildcard("{alva,alva_demo}/**/*.{ex,exs,ts}")

Enum.each(files, fn file ->
  content = File.read!(file)

  new_content =
    content
    |> String.replace("Alva.App.Info.Registry", "Alva.Registry")
    |> String.replace("Alva.App.Info", "Alva.Registry")
    |> String.replace("Alva.Domain.Info", "Alva.Registry")
    |> String.replace("Alva.Resource.Info", "Alva.Registry")

  if content != new_content do
    File.write!(file, new_content)
    IO.puts("Updated #{file}")
  end
end)
