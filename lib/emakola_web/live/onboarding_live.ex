defmodule EmakolaWeb.OnboardingLive do
  use EmakolaWeb, :live_view

  require Ash.Query

  @templates %{
    "research" => %{
      name: "Research Assistant",
      description: "Deep research across documents and web sources.",
      system_prompt:
        "You are a meticulous research assistant. Analyze topics thoroughly, cite sources when possible, and present findings in a clear, structured format.",
      temperature: 0.5,
      max_tokens: 4096
    },
    "code_review" => %{
      name: "Code Reviewer",
      description: "Automated PR reviews with security vulnerability detection.",
      system_prompt:
        "You are an expert code reviewer. Review code for bugs, security vulnerabilities, performance issues, and adherence to best practices.",
      temperature: 0.3,
      max_tokens: 8192
    },
    "writing" => %{
      name: "Content Writer",
      description: "Generate blog posts, documentation, and marketing copy.",
      system_prompt:
        "You are a skilled content writer. Create engaging, well-structured content tailored to the audience.",
      temperature: 0.8,
      max_tokens: 4096
    },
    "custom" => %{
      name: "Custom Agent",
      description: "Start from scratch with your own configuration.",
      system_prompt: "You are a helpful assistant.",
      temperature: 0.7,
      max_tokens: 4096
    }
  }

  def mount(_params, session, socket) do
    current_user =
      case session["user_token"] do
        nil ->
          nil

        token ->
          case AshAuthentication.subject_to_user(token, Emakola.Accounts.User) do
            {:ok, user} -> user
            _ -> nil
          end
      end

    if current_user && has_membership?(current_user.id) do
      {:ok,
       socket
       |> assign(current_user: current_user)
       |> put_flash(:info, "You've already completed onboarding")
       |> push_navigate(to: "/dashboard")}
    else
      {:ok,
       assign(socket,
         page_title: "Welcome",
         step: 1,
         total_steps: 4,
         current_user: current_user,
         org_name: "",
         invite_emails: [],
         invite_input: "",
         selected_template: nil,
         templates: @templates,
         error: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-background p-4">
      <div class="w-full max-w-lg space-y-8">
        <%!-- Progress --%>
        <div class="flex items-center gap-2">
          <div
            :for={i <- 1..@total_steps}
            class={[
              "h-1.5 flex-1 rounded-full transition-all duration-300",
              if(i <= @step, do: "bg-primary", else: "bg-surface-container-highest")
            ]}
          >
          </div>
        </div>
        <p class="text-xs font-mono text-on-surface-variant text-center">
          Step {@step} of {@total_steps}
        </p>

        <%!-- Error display --%>
        <div
          :if={@error}
          class="flex items-center gap-2 bg-error/10 text-error text-sm font-medium p-4 rounded-xl"
        >
          <span class="material-symbols-outlined text-lg">error</span>
          {@error}
        </div>

        <%!-- Step 1: Create Organisation --%>
        <div :if={@step == 1} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto">
            <span class="material-symbols-outlined text-3xl text-primary">apartment</span>
          </div>
          <h1 class="text-3xl font-extrabold font-headline">Create Your Organisation</h1>
          <p class="text-on-surface-variant">
            This is your workspace where your team and agents live.
          </p>
          <input
            type="text"
            name="org_name"
            value={@org_name}
            placeholder="Organisation name"
            phx-change="update_org_name"
            phx-debounce="300"
            autofocus
            class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface text-center focus:ring-2 focus:ring-primary"
          />
          <p :if={String.trim(@org_name) == ""} class="text-xs text-on-surface-variant/50">
            You'll be able to change this later in Settings
          </p>
        </div>

        <%!-- Step 2: Invite Team --%>
        <div :if={@step == 2} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto">
            <span class="material-symbols-outlined text-3xl text-primary">group_add</span>
          </div>
          <h1 class="text-3xl font-extrabold font-headline">Invite Your Team</h1>
          <p class="text-on-surface-variant">
            Add team members by email. You can always do this later.
          </p>
          <form phx-submit="add_invite" class="flex gap-2">
            <input
              type="email"
              name="email"
              value={@invite_input}
              placeholder="teammate@company.com"
              autofocus
              class="flex-1 bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface focus:ring-2 focus:ring-primary"
            />
            <button
              type="submit"
              class="primary-gradient px-4 py-2.5 rounded-lg text-sm font-semibold"
            >
              Add
            </button>
          </form>
          <div :if={@invite_emails != []} class="flex flex-wrap gap-2 justify-center">
            <span
              :for={email <- @invite_emails}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 text-primary text-xs font-medium rounded-full"
            >
              {email}
              <button
                type="button"
                phx-click="remove_invite"
                phx-value-email={email}
                class="hover:text-error transition-colors cursor-pointer"
              >
                <span class="material-symbols-outlined text-[14px]">close</span>
              </button>
            </span>
          </div>
          <p :if={@invite_emails == []} class="text-xs text-on-surface-variant/50">
            They'll receive an email with a link to create their account
          </p>
        </div>

        <%!-- Step 3: Create First Agent --%>
        <div :if={@step == 3} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mx-auto">
            <span class="material-symbols-outlined text-3xl text-primary">smart_toy</span>
          </div>
          <h1 class="text-3xl font-extrabold font-headline">Create Your First Agent</h1>
          <p class="text-on-surface-variant">
            Choose a template to get started, or skip to create one later.
          </p>
          <div class="grid grid-cols-2 gap-3 text-left">
            <button
              :for={{key, tmpl} <- @templates |> Enum.sort()}
              type="button"
              phx-click="select_template"
              phx-value-template={key}
              class={[
                "bg-surface-container p-4 rounded-xl cursor-pointer transition-all border-2 text-left group",
                if(@selected_template == key,
                  do: "border-primary shadow-md bg-primary/5",
                  else: "border-transparent hover:bg-surface-container-high hover:border-primary/20"
                )
              ]}
            >
              <span class="material-symbols-outlined text-primary mb-2 group-hover:scale-110 transition-transform">
                {template_icon(key)}
              </span>
              <p class="text-sm font-bold text-on-surface">{tmpl.name}</p>
              <p class="text-[11px] text-on-surface-variant mt-1 line-clamp-2">{tmpl.description}</p>
            </button>
          </div>
        </div>

        <%!-- Step 4: All Set --%>
        <div :if={@step == 4} class="space-y-6 text-center">
          <div class="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center mx-auto">
            <span class="material-symbols-outlined text-4xl text-primary">rocket_launch</span>
          </div>
          <h1 class="text-3xl font-extrabold font-headline">You're All Set!</h1>
          <p class="text-on-surface-variant">
            Your workspace is ready. Let's see your agent in action.
          </p>
          <div class="bg-surface-container rounded-xl p-5 space-y-3 text-sm text-left">
            <div class="flex items-center gap-3">
              <span class="material-symbols-outlined text-primary text-lg">check_circle</span>
              <span class="text-on-surface font-medium">{@org_name}</span>
              <span class="text-on-surface-variant text-xs ml-auto">Organisation</span>
            </div>
            <div :if={@invite_emails != []} class="flex items-center gap-3">
              <span class="material-symbols-outlined text-primary text-lg">check_circle</span>
              <span class="text-on-surface font-medium">
                {length(@invite_emails)} invite(s) will be sent
              </span>
              <span class="text-on-surface-variant text-xs ml-auto">Team</span>
            </div>
            <div :if={@invite_emails == []} class="flex items-center gap-3">
              <span class="material-symbols-outlined text-on-surface-variant/40 text-lg">
                remove_circle_outline
              </span>
              <span class="text-on-surface-variant">No team invites</span>
              <span class="text-on-surface-variant text-xs ml-auto">Skipped</span>
            </div>
            <div :if={@selected_template} class="flex items-center gap-3">
              <span class="material-symbols-outlined text-primary text-lg">check_circle</span>
              <span class="text-on-surface font-medium">{@templates[@selected_template].name}</span>
              <span class="text-on-surface-variant text-xs ml-auto">Agent</span>
            </div>
            <div :if={!@selected_template} class="flex items-center gap-3">
              <span class="material-symbols-outlined text-on-surface-variant/40 text-lg">
                remove_circle_outline
              </span>
              <span class="text-on-surface-variant">No agent selected</span>
              <span class="text-on-surface-variant text-xs ml-auto">Skipped</span>
            </div>
          </div>
        </div>

        <%!-- Navigation --%>
        <div class="flex justify-between items-center">
          <button
            :if={@step > 1}
            phx-click="prev_step"
            class="flex items-center gap-1 px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
          >
            <span class="material-symbols-outlined text-lg">arrow_back</span> Back
          </button>
          <div :if={@step == 1}></div>

          <div class="flex items-center gap-3">
            <button
              :if={@step == 2 or @step == 3}
              phx-click="next_step"
              class="px-4 py-2 text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
            >
              Skip
            </button>
            <button
              phx-click={if @step < @total_steps, do: "next_step", else: "complete"}
              disabled={@step == 1 and String.trim(@org_name) == ""}
              class={[
                "font-semibold px-6 py-2.5 rounded-lg text-sm flex items-center gap-2 transition-all",
                if(@step == 1 and String.trim(@org_name) == "",
                  do: "bg-surface-container-highest text-on-surface-variant/40 cursor-not-allowed",
                  else: "primary-gradient hover:scale-[1.02] active:scale-95"
                )
              ]}
            >
              {if @step < @total_steps, do: "Continue", else: "Go to Dashboard"}
              <span class="material-symbols-outlined text-lg">
                {if @step < @total_steps, do: "arrow_forward", else: "rocket_launch"}
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Events ──

  def handle_event("next_step", _, socket) do
    case validate_step(socket.assigns.step, socket.assigns) do
      :ok ->
        {:noreply,
         socket |> assign(error: nil) |> update(:step, &min(&1 + 1, socket.assigns.total_steps))}

      {:error, msg} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, update(socket, :step, &max(&1 - 1, 1))}
  end

  def handle_event("update_org_name", %{"org_name" => name}, socket) do
    {:noreply, assign(socket, org_name: name)}
  end

  def handle_event("add_invite", %{"email" => email}, socket) do
    email = String.trim(email)

    cond do
      email == "" ->
        {:noreply, assign(socket, invite_input: "")}

      not valid_email?(email) ->
        {:noreply, assign(socket, error: "Please enter a valid email address.")}

      email in socket.assigns.invite_emails ->
        {:noreply, assign(socket, invite_input: "", error: "This email has already been added.")}

      true ->
        {:noreply,
         assign(socket,
           invite_emails: socket.assigns.invite_emails ++ [email],
           invite_input: "",
           error: nil
         )}
    end
  end

  def handle_event("remove_invite", %{"email" => email}, socket) do
    {:noreply, assign(socket, invite_emails: List.delete(socket.assigns.invite_emails, email))}
  end

  def handle_event("select_template", %{"template" => key}, socket) do
    if Map.has_key?(@templates, key) do
      {:noreply, assign(socket, selected_template: key)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("complete", _, socket) do
    user = socket.assigns.current_user
    org_name = socket.assigns.org_name
    selected = socket.assigns.selected_template

    cond do
      is_nil(user) ->
        {:noreply, assign(socket, error: "You must be logged in to complete onboarding.")}

      org_name == "" ->
        {:noreply, assign(socket, error: "Please provide an organisation name.", step: 1)}

      true ->
        case create_workspace(user, org_name, selected) do
          {:ok, _org, agent} when not is_nil(agent) ->
            send_invite_emails(socket.assigns.invite_emails, org_name)

            {:noreply,
             socket
             |> put_flash(:info, "Welcome to Emakola!")
             |> push_navigate(to: "/agents/#{agent.id}")}

          {:ok, _org, nil} ->
            send_invite_emails(socket.assigns.invite_emails, org_name)

            {:noreply,
             socket
             |> put_flash(:info, "Welcome to Emakola!")
             |> push_navigate(to: "/dashboard")}

          {:error, reason} ->
            {:noreply, assign(socket, error: "Setup failed: #{reason}")}
        end
    end
  end

  # ── Helpers ──

  defp create_workspace(user, org_name, selected_template) do
    with {:ok, org} <-
           Emakola.Accounts.Organisation
           |> Ash.Changeset.for_create(:create, %{name: String.trim(org_name)})
           |> Ash.create(),
         {:ok, _membership} <-
           Emakola.Accounts.Membership
           |> Ash.Changeset.for_create(:create, %{
             role: :owner,
             user_id: user.id,
             organisation_id: org.id
           })
           |> Ash.create() do
      agent = create_agent_from_template(selected_template, org.id)
      {:ok, org, agent}
    else
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp create_agent_from_template(nil, _org_id), do: nil

  defp create_agent_from_template(template_key, org_id) do
    case Map.get(@templates, template_key) do
      nil ->
        nil

      tmpl ->
        case Emakola.AI.Agent
             |> Ash.Changeset.for_create(:create, %{
               name: tmpl.name,
               description: tmpl.description,
               system_prompt: tmpl.system_prompt,
               model: "claude-sonnet-4-20250514",
               provider: :anthropic,
               temperature: tmpl.temperature,
               max_tokens: tmpl.max_tokens,
               organisation_id: org_id
             })
             |> Ash.create() do
          {:ok, agent} -> agent
          {:error, _} -> nil
        end
    end
  end

  defp template_icon("research"), do: "science"
  defp template_icon("code_review"), do: "code"
  defp template_icon("writing"), do: "edit_note"
  defp template_icon("custom"), do: "tune"
  defp template_icon(_), do: "smart_toy"

  defp validate_step(1, assigns) do
    if String.trim(assigns.org_name) == "",
      do: {:error, "Please enter an organisation name."},
      else: :ok
  end

  defp validate_step(2, assigns) do
    pending = String.trim(assigns.invite_input)

    if pending != "" and not valid_email?(pending) do
      {:error, "Please enter a valid email address or clear the input."}
    else
      :ok
    end
  end

  defp validate_step(_, _), do: :ok

  defp valid_email?(email) do
    String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  end

  defp send_invite_emails([], _org_name), do: :ok

  defp send_invite_emails(emails, org_name) do
    Enum.each(emails, fn email ->
      Task.start(fn ->
        Emakola.Notifications.InviteMailer.invite(email, org_name)
      end)
    end)
  end

  defp has_membership?(user_id) do
    case Emakola.Accounts.Membership
         |> Ash.Query.filter(user_id: user_id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
