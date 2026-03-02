;;; alloy-mode.el --- Major mode for the Alloy 6 specification language -*- lexical-binding: t; -*-

;; Author: Vincent Lu
;; URL: https://github.com/vincentlu/alloy-mode
;; Version: 0.1.0
;; Keywords: languages
;; Package-Requires: ((emacs "25.1"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A major mode for editing Alloy 6 specifications (.als files).
;; Provides syntax highlighting, indentation, comment handling, and imenu.
;;
;; Usage:
;;   (require 'alloy-mode)
;; Opening a .als file will activate alloy-mode automatically.

;;; Code:

(require 'cl-lib)

;; ---- Customization ----

(defgroup alloy-mode nil
  "Major mode for editing Alloy specifications."
  :group 'languages)

(defcustom alloy-mode-indent-offset 2
  "Number of spaces for each indentation level in `alloy-mode'."
  :type 'integer)

;; ---- Syntax table ----

(defvar alloy-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Block comments: /* ... */
    (modify-syntax-entry ?/ ". 14" table)
    (modify-syntax-entry ?* ". 23" table)
    ;; Line comments: // handled via syntax-propertize (-- conflicts with operators)
    ;; Newline ends line comments
    (modify-syntax-entry ?\n "> b" table)
    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    ;; Word constituents
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?$ "w" table)
    ;; Punctuation
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    table)
  "Syntax table for `alloy-mode'.")

;; Use syntax-propertize to handle // and -- line comments, since -- can't be
;; expressed in a standard syntax table without conflicting with the minus operator.
(defvar alloy-mode--syntax-propertize-function
  (syntax-propertize-rules
   ("\\(//\\).*$" (1 "< b"))
   ("\\(--\\).*$" (1 "< b")))
  "Syntax-propertize rules for Alloy line comments.")

;; ---- Keywords ----

(defvar alloy-mode--declaration-keywords
  '("module" "open" "sig" "fact" "pred" "fun" "assert"
    "enum" "let" "run" "check")
  "Alloy declaration/command keywords.")

(defvar alloy-mode--modifier-keywords
  '("abstract" "extends" "in" "as" "for" "but" "expect"
    "exactly" "private" "var" "disj" "else")
  "Alloy modifier keywords.")

(defvar alloy-mode--quantifier-keywords
  '("all" "no" "some" "lone" "one" "sum" "set" "seq")
  "Alloy quantifier and multiplicity keywords.")

(defvar alloy-mode--operator-keywords
  '("not" "and" "or" "implies" "iff"
    "always" "eventually" "after" "before"
    "historically" "once" "until" "since"
    "releases" "triggered" "int")
  "Alloy keyword-form operators (logical and temporal).")

(defvar alloy-mode--builtin-atoms
  '("this" "iden" "none" "univ" "Int")
  "Alloy built-in atoms.")

;; ---- Font-lock ----

(defvar alloy-mode-font-lock-keywords
  (let ((decl-re (regexp-opt alloy-mode--declaration-keywords 'symbols))
        (mod-re (regexp-opt alloy-mode--modifier-keywords 'symbols))
        (quant-re (regexp-opt alloy-mode--quantifier-keywords 'symbols))
        (op-re (regexp-opt alloy-mode--operator-keywords 'symbols))
        (builtin-re (regexp-opt alloy-mode--builtin-atoms 'symbols)))
    `(
      ;; Sig names: "sig Foo, Bar"
      (,(concat "\\<sig\\>\\s-+\\(" "[a-zA-Z_$][a-zA-Z0-9_$\"]*"
                "\\(?:\\s-*,\\s-*[a-zA-Z_$][a-zA-Z0-9_$\"]*\\)*" "\\)")
       (1 font-lock-type-face))
      ;; Enum name: "enum Color"
      ("\\<enum\\>\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)"
       (1 font-lock-type-face))
      ;; Extends/in type refs: "extends Base" or "in A + B"
      ("\\<extends\\>\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)"
       (1 font-lock-type-face))
      ;; Pred/fun names: "pred foo" or "fun bar"
      ("\\<\\(?:pred\\|fun\\)\\>\\s-+\\(?:[a-zA-Z_$][a-zA-Z0-9_$\"]*/\\)?\\(?:[a-zA-Z_$][a-zA-Z0-9_$\"]*\\.\\)?\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)"
       (1 font-lock-function-name-face))
      ;; Fact/assert names: "fact myFact" or "assert myAssert"
      ("\\<\\(?:fact\\|assert\\)\\>\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)"
       (1 font-lock-constant-face))
      ;; Module name: "module foo/bar"
      ("\\<module\\>\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"/]*\\)"
       (1 font-lock-constant-face))
      ;; Open module: "open util/ordering"
      ("\\<open\\>\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"/]*\\)"
       (1 font-lock-constant-face))
      ;; Command label: "myTest:"
      ("^\\s-*\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)\\s-*:" (1 font-lock-constant-face))
      ;; Declaration keywords
      (,decl-re . font-lock-keyword-face)
      ;; Modifier keywords
      (,mod-re . font-lock-keyword-face)
      ;; Quantifier/multiplicity keywords
      (,quant-re . font-lock-keyword-face)
      ;; Keyword-form operators
      (,op-re . font-lock-keyword-face)
      ;; Built-in atoms
      (,builtin-re . font-lock-builtin-face)
      ;; @name references
      ("@\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" (0 font-lock-variable-name-face))
      ;; Numeric literals (decimal, hex, binary)
      ("\\<0x[0-9A-Fa-f_]+\\>" . font-lock-number-face)
      ("\\<0b[01_]+\\>" . font-lock-number-face)
      ("\\<[0-9][0-9_]*\\>" . font-lock-number-face)))
  "Font-lock keywords for `alloy-mode'.")

;; ---- Indentation ----

(defun alloy-mode--indent-line ()
  "Indent the current line in `alloy-mode'."
  (let ((indent (alloy-mode--calculate-indent)))
    (when indent
      (let ((offset (- (current-column) (current-indentation))))
        (indent-line-to indent)
        (when (> offset 0)
          (forward-char offset))))))

(defun alloy-mode--calculate-indent ()
  "Calculate indentation for the current line."
  (save-excursion
    (beginning-of-line)
    (let ((cur-line (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
      ;; If line starts with closing brace, match the opening line's indent
      (if (string-match-p "^\\s-*[}\\])]" cur-line)
          (save-excursion
            (alloy-mode--goto-matching-open)
            (current-indentation))
        ;; Otherwise, base indent on previous non-blank line
        (let ((prev-indent 0)
              (prev-line ""))
          (save-excursion
            (when (alloy-mode--prev-nonblank-line)
              (setq prev-indent (current-indentation))
              (setq prev-line (buffer-substring-no-properties
                               (line-beginning-position) (line-end-position)))))
          ;; Increase indent if previous line opens a block
          (if (alloy-mode--opens-block-p prev-line)
              (+ prev-indent alloy-mode-indent-offset)
            prev-indent))))))

(defun alloy-mode--opens-block-p (line)
  "Return non-nil if LINE ends with an opening brace/bracket (ignoring comments)."
  (let ((stripped (replace-regexp-in-string
                   "\\(?://.*\\|--.*\\)$" "" line)))
    (string-match-p "[{(\\[]\\s-*$" stripped)))

(defun alloy-mode--prev-nonblank-line ()
  "Move to the previous non-blank, non-comment-only line. Return t if found."
  (let ((found nil))
    (while (and (not found) (= 0 (forward-line -1)))
      (unless (looking-at-p "^\\s-*\\(?:$\\|//\\|--\\)")
        (setq found t)))
    found))

(defun alloy-mode--goto-matching-open ()
  "Move to the line containing the matching open brace for the close on current line."
  (let ((depth 1))
    (while (and (> depth 0) (= 0 (forward-line -1)))
      (let ((line (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
        (setq depth (+ depth
                       (alloy-mode--count-char line ?} ?\] ?\))
                       (- (alloy-mode--count-char line ?{ ?\[ ?\())))))
    (when (< depth 0) (setq depth 0))))

(defun alloy-mode--count-char (str &rest chars)
  "Count occurrences of any of CHARS in STR (outside strings/comments)."
  (let ((count 0)
        (in-string nil)
        (i 0)
        (len (length str)))
    (while (< i len)
      (let ((c (aref str i)))
        (cond
         ;; Toggle string state
         ((and (= c ?\") (or (= i 0) (/= (aref str (1- i)) ?\\)))
          (setq in-string (not in-string)))
         ;; Line comment starts — stop counting
         ((and (not in-string) (< (1+ i) len)
               (or (and (= c ?/) (= (aref str (1+ i)) ?/))
                   (and (= c ?-) (= (aref str (1+ i)) ?-))))
          (setq i len)) ; break
         ;; Count matching chars
         ((and (not in-string) (memq c chars))
          (setq count (1+ count)))))
      (setq i (1+ i)))
    count))

;; ---- Imenu ----

(defvar alloy-mode-imenu-generic-expression
  `(("Sig" "^\\s-*\\(?:abstract\\s-+\\|lone\\s-+\\|one\\s-+\\|some\\s-+\\|private\\s-+\\|var\\s-+\\)*sig\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1)
    ("Pred" "^\\s-*\\(?:private\\s-+\\)?pred\\s-+\\(?:[a-zA-Z_$][a-zA-Z0-9_$\"]*\\.\\)?\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1)
    ("Fun" "^\\s-*\\(?:private\\s-+\\)?fun\\s-+\\(?:[a-zA-Z_$][a-zA-Z0-9_$\"]*\\.\\)?\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1)
    ("Fact" "^\\s-*fact\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1)
    ("Assert" "^\\s-*assert\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1)
    ("Enum" "^\\s-*\\(?:private\\s-+\\)?enum\\s-+\\([a-zA-Z_$][a-zA-Z0-9_$\"]*\\)" 1))
  "Imenu generic expression for `alloy-mode'.")

;; ---- Major mode ----

;;;###autoload
(define-derived-mode alloy-mode prog-mode "Alloy"
  "Major mode for editing Alloy 6 specifications.

\\{alloy-mode-map}"
  :group 'alloy-mode
  :syntax-table alloy-mode-syntax-table

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?://+\\|--+\\)\\s-*")

  ;; Syntax propertize (for // and -- line comments)
  (setq-local syntax-propertize-function alloy-mode--syntax-propertize-function)

  ;; Font-lock
  (setq-local font-lock-defaults '(alloy-mode-font-lock-keywords nil nil))

  ;; Indentation
  (setq-local indent-line-function #'alloy-mode--indent-line)
  (setq-local electric-indent-chars (append '(?} ?\] ?\)) electric-indent-chars))

  ;; Imenu
  (setq-local imenu-generic-expression alloy-mode-imenu-generic-expression))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.als\\'" . alloy-mode))

(provide 'alloy-mode)
;;; alloy-mode.el ends here
