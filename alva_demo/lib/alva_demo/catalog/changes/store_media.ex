defmodule AlvaDemo.Catalog.Changes.StoreMedia do
  use Ash.Resource.Change

  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      media_arg = Keyword.get(opts, :arg, :media)
      attribute = Keyword.get(opts, :attribute, :media_reference)

      media = Ash.Changeset.get_argument(changeset, media_arg)

      if media do
        source = Map.get(media, :source) || media

        target_dir = Path.join(:code.priv_dir(:alva_demo), "static/images")
        File.mkdir_p!(target_dir)

        original_name = Path.basename(source.filename)
        uuid = Ecto.UUID.generate()
        new_filename = "#{uuid}-#{original_name}"

        dest_path = Path.join(target_dir, new_filename)
        copy_upload!(source.path, dest_path)

        Ash.Changeset.force_change_attribute(changeset, attribute, new_filename)
      else
        changeset
      end
    end)
  end

  defp copy_upload!(source_path, dest_path) do
    source_path
    |> File.read!()
    |> then(&File.write!(dest_path, &1))
  end
end
