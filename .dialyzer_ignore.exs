# Dialyzer warning filters. Each entry is one of:
#   {"path/to/file.ex"}                       — silence all warnings in a file
#   {"path/to/file.ex", :warning_type}        — silence a specific warning type
#   {"path/to/file.ex", :warning_type, line}  — silence at a specific line
#
# Add entries here only after confirming the warning is a false positive
# (Ash macros and Phoenix LiveView generate code that dialyzer often
# mis-types). Keep this file short — every entry is technical debt.
[
  # `use AshPostgres.Repo` injects a default `all_tenants/0` whose body is a
  # `raise`, intended to be overridden only by apps that use schema-based
  # multitenancy. Emakola uses attribute-based multitenancy, so the default
  # is correct, but dialyzer flags the injected function as `:no_return` at
  # the `use` line. Pure macro artefact, no runtime concern.
  {"lib/emakola/repo.ex", :no_return, 2}
]
