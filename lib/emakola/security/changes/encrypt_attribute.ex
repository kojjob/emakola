defmodule Emakola.Security.Changes.EncryptAttribute do
  @moduledoc """
  Ash change that dual-writes a sensitive attribute to an encrypted shadow.

  Ciphertext authentication is bound to the row UUID. A blind-index destination
  may also be supplied for values that will need equality lookup after their
  legacy plaintext column is retired.
  """

  use Ash.Resource.Change

  alias Emakola.Security.FieldEncryption

  @impl true
  def init(opts) do
    with source when is_atom(source) <- opts[:source],
         encrypted when is_atom(encrypted) <- opts[:encrypted],
         context when is_binary(context) and context != "" <- opts[:context],
         blind_index when is_nil(blind_index) or is_atom(blind_index) <- opts[:blind_index] do
      {:ok, opts}
    else
      _ -> {:error, "requires :source, :encrypted and :context options"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    source = Keyword.fetch!(opts, :source)

    case Ash.Changeset.fetch_change(changeset, source) do
      {:ok, nil} ->
        changeset
        |> Ash.Changeset.force_change_attribute(Keyword.fetch!(opts, :encrypted), nil)
        |> maybe_clear_blind_index(opts)

      {:ok, plaintext} when is_binary(plaintext) ->
        protect(changeset, plaintext, opts)

      {:ok, _invalid} ->
        add_protection_error(changeset, source)

      :error ->
        changeset
    end
  end

  defp protect(changeset, plaintext, opts) do
    context = Keyword.fetch!(opts, :context)
    {changeset, record_id} = ensure_record_id(changeset)

    with record_id when is_binary(record_id) <- record_id,
         {:ok, encrypted} <-
           FieldEncryption.encrypt(plaintext, encrypted_context(context, record_id)),
         {:ok, blind_index} <- maybe_build_blind_index(plaintext, context, opts) do
      changeset
      |> Ash.Changeset.force_change_attribute(Keyword.fetch!(opts, :encrypted), encrypted)
      |> maybe_put_blind_index(opts, blind_index)
    else
      _error -> add_protection_error(changeset, Keyword.fetch!(opts, :source))
    end
  end

  defp maybe_build_blind_index(plaintext, context, opts) do
    if opts[:blind_index],
      do: FieldEncryption.blind_index(plaintext, context),
      else: {:ok, nil}
  end

  defp maybe_put_blind_index(changeset, opts, blind_index) do
    if field = opts[:blind_index],
      do: Ash.Changeset.force_change_attribute(changeset, field, blind_index),
      else: changeset
  end

  defp maybe_clear_blind_index(changeset, opts) do
    if field = opts[:blind_index],
      do: Ash.Changeset.force_change_attribute(changeset, field, nil),
      else: changeset
  end

  defp encrypted_context(context, record_id), do: "#{context}:#{record_id}"

  defp ensure_record_id(changeset) do
    case Ash.Changeset.get_attribute(changeset, :id) do
      record_id when is_binary(record_id) ->
        {changeset, record_id}

      _missing ->
        record_id = Ash.UUID.generate()
        {Ash.Changeset.force_change_attribute(changeset, :id, record_id), record_id}
    end
  end

  defp add_protection_error(changeset, source) do
    Ash.Changeset.add_error(changeset,
      field: source,
      message: "could not be protected because field encryption is unavailable"
    )
  end
end
