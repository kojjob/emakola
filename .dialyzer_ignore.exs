# Dialyzer warning filters. Each entry is one of:
#   {"path/to/file.ex"}                       — silence all warnings in a file
#   {"path/to/file.ex", :warning_type}        — silence a specific warning type
#   {"path/to/file.ex", :warning_type, line}  — silence at a specific line
#
# Add entries here only after confirming the warning is a false positive
# (Ash macros and Phoenix LiveView generate code that dialyzer often
# mis-types). Keep this file short — every entry is technical debt.
[]
