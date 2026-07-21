defmodule Alva.LiveView.Uploads do
  @moduledoc false

  alias Ash.Resource.Info

  @upload_change_event "alva.validate_upload"
  @upload_submit_event "alva.save_upload"

  def configure_file_uploads(socket, uploads, otp_app) do
    upload_arg_names =
      Enum.flat_map(uploads || [], fn upload_name ->
        fetch_upload_args(upload_name, otp_app)
      end)
      |> Enum.uniq()

    Enum.reduce(upload_arg_names, socket, fn arg_name, acc_socket ->
      Phoenix.LiveView.allow_upload(acc_socket, arg_name, accept: :any, auto_upload: true)
    end)
  end

  defp fetch_upload_args(upload_name, otp_app) do
    case Alva.Registry.fetch_event(otp_app, to_string(upload_name)) do
      {:ok, resource, event_def} ->
        case Info.action(resource, event_def.action) do
          nil -> []
          action -> extract_file_args(action.arguments)
        end

      _ ->
        []
    end
  end

  defp extract_file_args(arguments) do
    arguments
    |> Enum.filter(fn arg ->
      case arg.type do
        Ash.Type.File -> true
        {:array, Ash.Type.File} -> true
        _ -> false
      end
    end)
    |> Enum.map(& &1.name)
  end

  def upload_lifecycle_event?(event_name)
      when event_name in [@upload_change_event, @upload_submit_event],
      do: true

  def upload_lifecycle_event?(_event_name), do: false

  @upload_temp_dir_name "alva_uploads"

  @doc """
  Consumes uploaded files from the LiveView socket and injects them into the params.
  Returns a tuple `{updated_params, cleanup_paths}`.
  """
  @spec consume_uploads_into_params(map(), map(), map(), keyword()) :: {map(), [String.t()]}
  def consume_uploads_into_params(socket, action, params, opts) do
    consumer = Keyword.get(opts, :upload_consumer, Phoenix.LiveView)

    file_args =
      Enum.filter(action.arguments || [], fn arg ->
        arg.type == Ash.Type.File or arg.type == {:array, Ash.Type.File}
      end)

    Enum.reduce(file_args, {params, []}, fn arg, {acc_params, acc_cleanup_paths} ->
      upload_name = arg.name

      uploads = Map.get(socket.assigns || %{}, :uploads, %{})
      upload_config = Map.get(uploads, upload_name)
      entries = if upload_config, do: Map.get(upload_config, :entries, []), else: []

      if upload_config && entries != [] do
        {value, cleanup_paths} = consume_upload(consumer, socket, upload_name, arg.type)
        {Map.put(acc_params, to_string(upload_name), value), acc_cleanup_paths ++ cleanup_paths}
      else
        {acc_params, acc_cleanup_paths}
      end
    end)
  end

  @doc """
  Cleans up any persisted upload files that were stored temporarily.
  """
  @spec cleanup_persisted_uploads([String.t()]) :: :ok
  def cleanup_persisted_uploads(paths) do
    Enum.each(paths, &File.rm/1)
  end

  defp consume_upload(consumer, socket, upload_name, arg_type) do
    {consumed_files, cleanup_paths} =
      consumer.consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
        {:ok, persist_uploaded_entry(path, entry)}
      end)
      |> Enum.unzip()

    value = maybe_wrap_upload_list(consumed_files, arg_type)
    {value, cleanup_paths}
  end

  defp maybe_wrap_upload_list(files, {:array, _}), do: files
  defp maybe_wrap_upload_list(files, _), do: List.first(files)

  defp persist_uploaded_entry(path, entry) do
    upload_dir = Path.join(System.tmp_dir!(), @upload_temp_dir_name)
    File.mkdir_p!(upload_dir)

    original_name = entry.client_name || Path.basename(path)
    persisted_path = build_persisted_upload_path(upload_dir, original_name)
    File.cp!(path, persisted_path)

    {%Plug.Upload{path: persisted_path, filename: original_name, content_type: entry.client_type},
     persisted_path}
  end

  defp build_persisted_upload_path(upload_dir, original_name) do
    basename =
      original_name
      |> Path.basename()
      |> Path.rootname()
      |> String.replace(~r/[^A-Za-z0-9._-]+/, "_")
      |> String.trim("_")
      |> case do
        "" -> "upload"
        value -> value
      end

    ext = Path.extname(original_name)
    filename = "#{basename}-#{System.unique_integer([:positive])}#{ext}"
    Path.join(upload_dir, filename)
  end
end
