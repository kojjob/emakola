defmodule Emakola.Accounts.PlatformAuditSearchTest do
  @moduledoc """
  The ledger's filter model: parsing from URL params, the Ash page query,
  the per-family counts, the in-memory match used for live counts, the
  day bands, actor resolution, and the export stream.
  """
  use Emakola.DataCase, async: true

  import Ecto.Query

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformAuditSearch, as: Search
  alias Emakola.Factory

  defp log!(action, actor \\ nil, metadata \\ %{}, ip \\ nil) do
    {:ok, entry} = PlatformAudit.log(action, actor, metadata, ip)
    entry
  end

  defp backdate!(entry, days) do
    at = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.truncate(:second)

    {1, _} =
      Emakola.Repo.update_all(from(l in PlatformAuditLog, where: l.id == ^entry.id),
        set: [inserted_at: at]
      )

    %{entry | inserted_at: at}
  end

  defp actions(search, opts \\ []) do
    {:ok, %Ash.Page.Keyset{results: results}} = Search.page(search, opts)
    Enum.map(results, & &1.action)
  end

  describe "from_params/1 and to_params/1" do
    test "parses allowed values and trims the query" do
      search =
        Search.from_params(%{
          "family" => "stores",
          "severity" => "red",
          "range" => "week",
          "q" => "  41.215  "
        })

      assert %Search{family: :stores, severity: :red, range: :week, q: "41.215"} = search
    end

    test "junk falls back to the defaults" do
      assert %Search{family: :all, severity: :any, range: :all, q: ""} =
               Search.from_params(%{"family" => "evil", "severity" => "x", "range" => "y"})

      assert %Search{family: :all} = Search.from_params(%{})
    end

    test "to_params drops defaults so the URL stays short" do
      assert Search.to_params(%Search{}) == %{}

      assert Search.to_params(%Search{family: :stores, q: "osu"}) == %{
               "family" => "stores",
               "q" => "osu"
             }
    end
  end

  describe "page/2" do
    test "family filters to that family's actions" do
      log!(:store_suspended)
      log!(:sign_out)

      assert actions(%Search{family: :stores}) == [:store_suspended]
      assert actions(%Search{family: :sign_ins}) == [:sign_out]
    end

    test "severity filters by colour family" do
      log!(:sign_in_failed)
      log!(:sign_in_succeeded)
      log!(:permissions_changed)

      assert actions(%Search{severity: :red}) == [:sign_in_failed]
      assert actions(%Search{severity: :neutral}) == [:permissions_changed]
    end

    test "range hides entries older than the window" do
      log!(:sign_out) |> backdate!(3)
      log!(:sign_in_succeeded)

      assert actions(%Search{range: :day}) == [:sign_in_succeeded]
      assert :sign_out in actions(%Search{range: :week})
    end

    test "q matches the ip, the metadata text, or the actor's email" do
      staff = Factory.create_user!(%{email: "ama.owusu@example.com"})
      log!(:sign_out, nil, %{}, "10.9.8.7")
      log!(:store_featured, nil, %{"store_slug" => "kumasi-spice-co"})
      log!(:sign_in_succeeded, staff)
      log!(:totp_failed, nil, %{}, "1.2.3.4")

      assert actions(%Search{q: "10.9"}) == [:sign_out]
      assert actions(%Search{q: "KUMASI"}) == [:store_featured]
      assert actions(%Search{q: "ama.owusu"}) == [:sign_in_succeeded]
    end

    test "q treats LIKE wildcards literally" do
      log!(:sign_out, nil, %{"note" => "50% off"})
      log!(:sign_out, nil, %{"note" => "plain"})

      assert length(actions(%Search{q: "%"})) == 1
      assert actions(%Search{q: "_"}) == []
    end

    test "pages by keyset, newest first" do
      for _ <- 1..3, do: log!(:sign_out)

      {:ok, %Ash.Page.Keyset{results: [first, second], more?: true}} =
        Search.page(%Search{}, limit: 2)

      assert DateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]

      {:ok, %Ash.Page.Keyset{results: [_third], more?: false}} =
        Search.page(%Search{}, limit: 2, after: second.__metadata__.keyset)
    end
  end

  describe "counts/1" do
    test "counts every family plus the total, ignoring the family filter itself" do
      log!(:store_suspended)
      log!(:store_blocked)
      log!(:sign_out)

      counts = Search.counts(%Search{family: :stores})

      assert counts.all == 3
      assert counts.stores == 2
      assert counts.sign_ins == 1
      assert counts.finance == 0
    end

    test "counts respect severity, range and q" do
      log!(:store_blocked)
      log!(:store_suspended)
      log!(:sign_out, nil, %{}, "10.9.8.7")

      assert Search.counts(%Search{severity: :red}).all == 1
      assert Search.counts(%Search{q: "10.9"}).all == 1
    end
  end

  describe "matches?/2" do
    test "checks family, severity and range in memory" do
      entry = log!(:store_suspended)

      assert Search.matches?(%Search{}, entry)
      assert Search.matches?(%Search{family: :stores, severity: :amber, range: :day}, entry)
      refute Search.matches?(%Search{family: :finance}, entry)
      refute Search.matches?(%Search{severity: :red}, entry)
      refute Search.matches?(%Search{range: :day}, backdate!(entry, 2))
    end

    test "never matches while a text search is active" do
      entry = log!(:store_suspended, nil, %{}, "10.9.8.7")

      refute Search.matches?(%Search{q: "10.9"}, entry)
    end
  end

  describe "with_bands/2" do
    test "inserts a band before the first entry of each day" do
      newer = log!(:sign_out)
      older = log!(:sign_in_succeeded) |> backdate!(3)

      {items, last_date} = Search.with_bands([newer, older], nil)

      assert [
               %{kind: :band, date: today},
               %{kind: :entry, entry: ^newer},
               %{kind: :band, date: old_date, label: old_label},
               %{kind: :entry, entry: ^older}
             ] = items

      assert today == Date.utc_today()
      assert old_date == DateTime.to_date(older.inserted_at)
      assert old_label == Calendar.strftime(old_date, "%a %-d %b")
      assert last_date == old_date
    end

    test "labels today and yesterday by name" do
      today = log!(:sign_out)
      yesterday = log!(:sign_out) |> backdate!(1)

      {[%{label: today_label}, _, %{label: yesterday_label}, _], _} =
        Search.with_bands([today, yesterday], nil)

      assert today_label == "Today · " <> Calendar.strftime(Date.utc_today(), "%a %-d %b")
      assert String.starts_with?(yesterday_label, "Yesterday · ")
    end

    test "continues a day already banded on the previous page" do
      entry = log!(:sign_out)

      {items, _} = Search.with_bands([entry], Date.utc_today())

      assert [%{kind: :entry}] = items
    end

    test "band ids are stable per date" do
      entry = log!(:sign_out)

      {[%{id: id} | _], _} = Search.with_bands([entry], nil)

      assert id == "band-" <> Date.to_iso8601(Date.utc_today())
    end
  end

  describe "actor_names/2" do
    test "resolves new actor ids once and keeps what it already knows" do
      staff = Factory.create_user!()
      known = %{"abc" => %{name: "Known", email: "known@example.com"}}
      entries = [log!(:sign_in_succeeded, staff), log!(:sign_in_failed, nil)]

      actors = Search.actor_names(known, entries)

      assert actors["abc"].name == "Known"
      assert actors[staff.id].email == to_string(staff.email)
      refute Map.has_key?(actors, nil)
    end
  end

  describe "stream/2" do
    test "walks every page of the filtered set, newest first" do
      log!(:sign_out)
      log!(:store_suspended)
      log!(:store_blocked)
      log!(:store_featured)

      streamed = %Search{family: :stores} |> Search.stream(page_size: 2) |> Enum.to_list()

      assert Enum.map(streamed, & &1.action) == [:store_blocked, :store_suspended]
    end
  end
end
