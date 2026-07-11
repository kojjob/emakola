# Dialyzer warning filters. Each entry is one of:
#   {"path/to/file.ex"}                       — silence all warnings in a file
#   {"path/to/file.ex", :warning_type}        — silence a specific warning type
#   {"path/to/file.ex", :warning_type, line}  — silence at a specific line
#
# Add entries here only after confirming the warning is a false positive
# (Ash macros and Phoenix LiveView generate code that dialyzer often
# mis-types). Keep this file short — every entry is technical debt.
[
  {"lib/ash_authentication_phoenix/controller.ex", :unknown_type},
  {"lib/emakola/analytics/pdf_report.ex", :invalid_contract},
  {"lib/emakola/dashboard/dashboard_stats.ex", :pattern_match},
  {"lib/emakola/platform/stats.ex", :guard_fail},
  {"lib/emakola/repo.ex", :no_return, 2},
  {"lib/emakola_web/controllers/export_controller.ex", :pattern_match},
  {"lib/emakola_web/live/dashboard/dashboard_helpers.ex", :guard_fail}
]
