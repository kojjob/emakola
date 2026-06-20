defmodule Emakola.Content.Workers.BlogGeneratorWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  alias Emakola.Content.RateLimiter
  alias Emakola.Content.Workers.BlogGeneratorWorker

  setup :verify_on_exit!

  setup do
    {:ok, store: create_store!()}
  end

  defp draft_post(store_id) do
    {:ok, posts} = Emakola.Content.list_posts_by_store(store_id, authorize?: false)
    Enum.find(posts, &(&1.status == :ai_draft))
  end

  test "creates an ai_draft post from a topic", %{store: store} do
    expect(Emakola.Content.GeneratorMock, :generate_blog_post, fn topic, _store, type ->
      assert topic == "How to store yams"
      assert type == :blog_post

      {:ok,
       %{
         title: "Storing Yams 101",
         body: "## Tips\nKeep them cool.",
         excerpt: "Keep yams fresh longer.",
         tags: ["yams", "storage"]
       }}
    end)

    assert :ok =
             perform_job(BlogGeneratorWorker, %{
               "store_id" => store.id,
               "topic" => "How to store yams"
             })

    post = draft_post(store.id)
    assert post.title == "Storing Yams 101"
    assert post.status == :ai_draft
    assert post.ai_generated == true
    assert post.type == :blog_post
  end

  test "honors the guide type", %{store: store} do
    expect(Emakola.Content.GeneratorMock, :generate_blog_post, fn _topic, _store, type ->
      assert type == :guide
      {:ok, %{title: "A Guide", body: "b", excerpt: "e", tags: []}}
    end)

    assert :ok =
             perform_job(BlogGeneratorWorker, %{
               "store_id" => store.id,
               "topic" => "x",
               "type" => "guide"
             })

    assert draft_post(store.id).type == :guide
  end

  test "cancels when the generator is not configured", %{store: store} do
    expect(Emakola.Content.GeneratorMock, :generate_blog_post, fn _, _, _ ->
      {:error, :not_configured}
    end)

    assert {:cancel, _} =
             perform_job(BlogGeneratorWorker, %{"store_id" => store.id, "topic" => "x"})
  end

  test "cancels when the store hit its daily AI limit", %{store: store} do
    for _ <- 1..RateLimiter.default_limit(), do: RateLimiter.check_and_increment(store.id)

    assert {:cancel, _} =
             perform_job(BlogGeneratorWorker, %{"store_id" => store.id, "topic" => "x"})
  end
end
