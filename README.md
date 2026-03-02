# alloy-mode

An Emacs major mode for editing [Alloy 6](https://alloytools.org/)
specifications (`.als` files).

Provides syntax highlighting, indentation, comment handling, and imenu.
No tree-sitter or external dependencies required — works on any Emacs 25.1+.

For tree-sitter-based highlighting and indentation, see
[alloy-ts-mode](https://github.com/vincentlu/alloy-ts-mode) (Emacs 29+).

## Installation

Add `alloy-mode.el` to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/alloy-mode")
(require 'alloy-mode)
```

Opening a `.als` file will activate `alloy-mode` automatically.

## Features

- **Syntax highlighting** — keywords, types, functions, predicates, operators,
  built-in atoms, numbers, strings, comments
- **Indentation** — brace-based with `alloy-mode-indent-offset` (default 2)
- **Comments** — `//`, `--`, and `/* */`; `M-;` works as expected
- **Imenu** — navigate to sigs, preds, funs, facts, asserts, and enums

## LSP support

Pair with [alloy-lsp](https://github.com/vincentlu/alloy-lsp) for
CodeLens, execution, and output:

```elisp
(use-package alloy-lsp
  :hook (alloy-mode . alloy-lsp-ensure))
```

## License

[GPL-3.0-or-later](LICENSE)
