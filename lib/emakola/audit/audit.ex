defmodule Emakola.Audit do
  @moduledoc """
  Audit domain for GDPR/SOC2 compliance.

  Provides an immutable event log recording all significant actions across
  the application. Call `Audit.log/6` from other contexts after significant
  actions to create tamper-proof audit trail entries.
  """

  use Ash.Domain

  resources do
    resource Emakola.Audit.AuditLog do
      define(:create_log, action: :create)
      define(:list_logs, action: :read)
      define(:list_by_resource, action: :by_resource, args: [:resource_type, :resource_id])
      define(:list_by_actor, action: :by_actor, args: [:actor_id])
      define(:list_by_organisation, action: :by_organisation, args: [:organisation_id])
    end
  end

  @doc """
  Log an audit event. Call this from other contexts after significant actions.

  ## Parameters
    - `action` - One of the allowed action atoms (e.g., :create, :update, :login)
    - `resource_type` - String identifying the resource type (e.g., "User", "Agent")
    - `resource_id` - String identifying the specific resource
    - `actor_id` - UUID of the user who performed the action (nil for system actions)
    - `org_id` - UUID of the organisation context (nil if not applicable)
    - `opts` - Keyword list of optional fields:
      - `:changes` - Map of field changes (default: %{})
      - `:metadata` - Map of additional context (default: %{})
      - `:ip_address` - Client IP address string
      - `:user_agent` - Client user agent string

  ## Examples

      Audit.log(:create, "User", user.id, actor.id, org.id,
        changes: %{email: "new@example.com"},
        ip_address: "127.0.0.1"
      )

      Audit.log(:login, "Session", session_id, user.id, nil)
  """
  def log(action, resource_type, resource_id, actor_id, org_id, opts \\ []) do
    attrs = %{
      action: action,
      resource_type: resource_type,
      resource_id: to_string(resource_id),
      actor_id: actor_id,
      organisation_id: org_id,
      changes: Keyword.get(opts, :changes, %{}),
      metadata: Keyword.get(opts, :metadata, %{}),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent)
    }

    Emakola.Audit.AuditLog
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end
end
