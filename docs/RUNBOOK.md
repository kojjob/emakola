# Runbook

The handful of things you do to makola.io in production, each as one command
you can paste. App name on Fly is `emakola`. Every `rpc` line runs inside the
live app with the database attached; `eval` would not, so never swap them.

## Deploy main

Merge to `main` first. Then, from a checkout of `main`:

```bash
nohup fly deploy -a emakola > /tmp/deploy.log 2>&1 &
tail -f /tmp/deploy.log
```

`nohup` matters: a deploy takes several minutes and a shell that times out at
two minutes kills it half way. Migrations run in the release step; look for
`release_command ... completed successfully` in the log.

Confirm it landed:

```bash
fly releases -a emakola | head -3
curl -sI https://makola.io | head -1
```

## Roll back

Find the image of the last good release, then deploy it. No build, about a
minute.

```bash
fly releases -a emakola --image | head -4
fly deploy -a emakola --image registry.fly.io/emakola:deployment-<ID FROM THE GOOD ROW>
```

Rolling back code does not roll back a migration that already ran. Additive
migrations (new columns with defaults) are safe to leave; only worry when a
migration dropped or renamed something.

## Run something inside the live app

```bash
fly ssh console -a emakola -C "/app/bin/emakola rpc '<elixir here>'"
```

Quote carefully: the outer quotes are double, the Elixir is inside single
quotes, so any string inside the Elixir uses `\"`.

## Seed or refresh the platform blog

Blog posts live in `priv/platform_blog/*.html` and are written to the database
by a seeder, not by a deploy. After any deploy that adds or edits a post:

```bash
fly ssh console -a emakola -C "/app/bin/emakola rpc 'IO.inspect(Emakola.Content.PlatformBlogSeeder.seed())'"
```

Safe to run twice; it matches posts by slug and refreshes their content.

## Set or rotate a secret

```bash
fly secrets set -a emakola NAME="value"
fly secrets set -a emakola GSC_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/makola-gsc-*.json)"
fly secrets list -a emakola
```

Setting a secret restarts the app. `secrets list` shows a digest, never the
value; that is how you check whether something is set without seeing it.

## Archive a shop

Archiving keeps every row and can be undone with `:reactivate`. It removes the
shop from the directory and the sitemap index at once.

```bash
fly ssh console -a emakola -C "/app/bin/emakola rpc '{:ok, s} = Emakola.Stores.get_store_by_slug(\"the-slug\", authorize?: false); s |> Ash.Changeset.for_update(:archive, %{reason: \"why\"}) |> Ash.update!(authorize?: false) |> then(&IO.inspect({&1.slug, &1.status}))'"
```

Look before you archive: load `:orders` and `:product_count` on the store and
read them.

## Search Console

Property: `sc-domain:makola.io`, which covers every shop subdomain.

- Sitemap submitted: `https://makola.io/sitemap.xml`. It is an index of every
  live shop with products, built on each request; nothing to resubmit.
- Read what is indexed: Indexing, Pages. Read what people searched: Performance.
- The app pulls the same data daily (`GscSyncWorker`). To check the API link
  works:

```bash
fly ssh console -a emakola -C "/app/bin/emakola rpc 'IO.inspect(Emakola.Analytics.GscFetcher.fetch(nil))'"
```

`{:ok, [rows]}` is good. `{:ok, []}` with the secret set means the service
account is not a user on the property, or there is no data yet.

## Logs

```bash
fly logs -a emakola
fly logs -a emakola | grep -i error
```
