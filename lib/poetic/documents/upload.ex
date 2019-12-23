defmodule Poetic.Documents.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "uploads" do
    field :content_type, :string
    field :filename, :string
    field :hash, :string
    field :size, :integer
    field :thumbnail?, :boolean, source: :has_thumb

    timestamps()
  end

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:filename, :size, :content_type, :hash, :thumbnail?])
    |> validate_required([:filename, :size, :content_type, :hash])
    # doesn't allow empty files
    |> validate_number(:size, greater_than: 0)
    |> validate_length(:hash, is: 64)
  end

  def sha256(chunks_enum) do
    chunks_enum
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  def local_path(id, filename) do
    [upload_dir(), "#{id}-#{filename}"]
    |> Path.join()
  end

  def upload_dir() do
    Application.get_env(:poetic, :uploads_directory)
  end

  def thumbnail_path(id) do
    [upload_dir(), "thumb-#{id}.jpg"]
    |> Path.join()
  end

  def creat_thumbnail(%__MODULE__{ content_type: "image/" <> _img_type } = upload) do
    original_path = local_path(upload.id, upload.filename)
    thumb_path = thumbnail_path(upload.id)
    { :ok, _ } = mogrify_thumbnail(original_path, thumb_path)

    changeset(upload, %{ thumbnail?: true })
  end

  def mogrify_thumbnail(src_path, dest_path) do
    try do
      Mogrify.open(src_path)
      |> Mogrify.resize_to_limit("300x300")
      |> Mogrify.save(path: dest_path)
    rescue
      File.Error -> {:error, :invalid_src_path}
      error -> {:error, error}
    else
      _image -> {:ok, dest_path}
    end
  end
end
