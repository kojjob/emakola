defmodule Mix.Tasks.Emakola.BackfillImageVariantsTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Workers.ImageProcessorWorker

  test "enqueues pending and failed images, skips completed ones" do
    store = create_store!()
    product = create_product!(store)

    pending = create_image!(product, store)
    failed = create_image!(product, store)

    failed
    |> Ash.Changeset.for_update(:mark_failed, %{})
    |> Ash.update!(authorize?: false)

    completed = create_image!(product, store)

    completed
    |> Ash.Changeset.for_update(:mark_processed, %{
      thumbnail_url: "https://s3.example.com/t.webp",
      medium_url: "https://s3.example.com/m.webp"
    })
    |> Ash.update!(authorize?: false)

    # Creation itself enqueues; clear so the assertions see only the backfill.
    Repo.delete_all(Oban.Job)

    Mix.Tasks.Emakola.BackfillImageVariants.run([])

    assert_enqueued(worker: ImageProcessorWorker, args: %{"image_id" => pending.id})
    assert_enqueued(worker: ImageProcessorWorker, args: %{"image_id" => failed.id})
    refute_enqueued(worker: ImageProcessorWorker, args: %{"image_id" => completed.id})
  end
end
