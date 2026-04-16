%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/priv/"
        ]
      },
      checks: %{
        enabled: [
          # Re-enabled: all modules now have @moduledoc.
          {Credo.Check.Readability.ModuleDoc, []},

          # TODOs are intentional markers, not issues
          {Credo.Check.Design.TagTODO, false},

          # Relax complexity for existing FounderPad code
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]},

          # Allow nested module references (common in Ash Error modules)
          {Credo.Check.Readability.AliasAs, false}
        ]
      }
    }
  ]
}
