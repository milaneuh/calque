# .formatter.exs
[
  import_deps: [:credo, :ex_doc],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  line_length: 100
]
