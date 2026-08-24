defmodule Emakola.Conversations.Message do
  @moduledoc """
  One message in a thread.

  `author_kind` + `author_id` rather than three nullable foreign keys: the
  author is a merchant, a customer, or Makola staff, and those live in three
  different tables. The kind is a small fixed set, so a wrong value cannot be
  written even though the id is not constrained by the database.

  Messages are never edited or deleted — a shop and a buyer disagreeing about
  what was promised is exactly when the record has to be trustworthy.
  """

  use Ash.Resource,
    domain: Emakola.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversation_messages")
    repo(Emakola.Repo)

    references do
      reference(:thread, on_delete: :delete)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :thread_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :author_kind, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:merchant, :customer, :platform])
    end

    attribute :author_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 4000)
    end

    timestamps()
  end

  relationships do
    belongs_to :thread, Emakola.Conversations.Thread do
      allow_nil?(false)
      attribute_writable?(true)
    end
  end

  policies do
    bypass action_type(:create) do
      authorize_if(always())
    end

    bypass action_type(:action) do
      authorize_if(always())
    end

    policy action_type([:read, :update]) do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :post do
      accept([:thread_id, :author_kind, :author_id, :body])
    end

    read :for_thread do
      argument :thread_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(thread_id == ^arg(:thread_id)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :unread_for_thread do
      argument :thread_id, :uuid do
        allow_nil?(false)
      end

      argument :since, :utc_datetime_usec do
        allow_nil?(true)
      end

      argument :exclude_kind, :atom do
        allow_nil?(false)
      end

      # A nil `since` means "never read" — everything from the other side
      # counts. Written as an or-expression rather than two actions so the
      # first-visit case cannot drift from the rest.
      filter(
        expr(
          thread_id == ^arg(:thread_id) and author_kind != ^arg(:exclude_kind) and
            (is_nil(^arg(:since)) or inserted_at > ^arg(:since))
        )
      )
    end
  end
end
