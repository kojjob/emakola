defmodule Mix.Tasks.Emakola.BackfillImageVariants do
  @shortdoc "Enqueues webp variant generation for every unprocessed image"

  @moduledoc """
  Enqueues `Emakola.Workers.ImageProcessorWorker` for every image that has no
  variants yet (status :pending or :failed). Safe to re-run: the worker skips
  completed images and its unique constraint absorbs duplicate jobs.

      mix emakola.backfill_image_variants
  """

  use Mix.Task

  require Ash.Query

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    count =
      Emakola.Catalog.Image
      |> Ash.Query.filter(processing_status != :completed)
      |> Ash.stream!(authorize?: false)
      |> Enum.reduce(0, fn image, enqueued ->
        Emakola.Workers.ImageProcessorWorker.enqueue(image.id)
        enqueued + 1
      end)

    Mix.shell().info("Enqueued #{count} images for variant generation")
  end
end
