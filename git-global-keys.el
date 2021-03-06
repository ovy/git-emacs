;; Global keys for git-emacs.
;;
;; See git-emacs.el for license and versioning.

(require 'easymenu)

(defcustom git-keyboard-prefix "\C-xg"
  "Keyboard prefix to use for global git keyboard commands."
  :type 'string
  :group 'git-emacs)

(define-prefix-command 'git-global-map)
(define-key global-map git-keyboard-prefix 'git-global-map)

(define-key git-global-map "a" 'git-add)
(define-key git-global-map "A" 'git-add-new)
(define-key git-global-map "b" 'git-branch)

(define-prefix-command 'git--commit-map nil "Commit")
(define-key git-global-map "c" 'git--commit-map)
(define-key git--commit-map "f" '("[f]ile" . git-commit-file))
(define-key git--commit-map "i" '("[i]ndex" . git-commit))
(define-key git--commit-map "a" '("[a]ll" . git-commit-all))
(define-key git--commit-map (kbd "RET") 'git-commit-all)

(define-prefix-command 'git--diff-buffer-map nil "Diff against")
(define-key git-global-map "d" 'git--diff-buffer-map)
(define-key git--diff-buffer-map "o" '("[o]ther" . git-diff-other))
(define-key git--diff-buffer-map "i" '("[i]ndex" . git-diff-index))
(define-key git--diff-buffer-map "u" '("[u]pstream" . git-diff-upstream))
(define-key git--diff-buffer-map "h" '("[H]ead" . git-diff-head))
(define-key git--diff-buffer-map (kbd "RET") 'git-diff-head)

(define-prefix-command 'git--diff-all-map nil "Diff repo against")
(define-key git-global-map "D" 'git--diff-all-map)
(define-key git--diff-all-map "o" '("[o]ther" . git-diff-all-other))
(define-key git--diff-all-map "i" '("[i]ndex" . git-diff-all-index))
(define-key git--diff-all-map "u" '("[u]pstream" . git-diff-all-upstream))
(define-key git--diff-all-map "h" '("[H]ead" . git-diff-all-head))
(define-key git--diff-all-map (kbd "RET") 'git-diff-all-head)

(define-key git-global-map "g" 'git-grep)
(define-key git-global-map "h" 'git-stash)
(define-key git-global-map "r" 'git-rename)
(define-key git-global-map "i" 'git-add-interactively)

(define-key git-global-map "l" 'git-log)
(define-key git-global-map "L" 'git-log-files)
(define-key git-global-map "\C-l" 'git-log-other)

(define-key git-global-map "m" 'git-merge-next-action)

(define-key git-global-map "p" 'git-pull)
(define-key git-global-map "P" 'git-push)

(define-key git-global-map "R" 'git-reset)

(define-key git-global-map "s" 'git-status)
(define-key git-global-map "." 'git-cmd)

(easy-menu-add-item nil '("tools")
  `("Git-emacs"
    ("Add to Index"
     ["Current File" git-add t]
     ["Select Changes in Current File..." git-add-interactively t]
     ["New Files..." git-add-new t])
    ("Commit"
     ["All Changes" git-commit-all t]
     ["Index" git-commit t]
     ["Current File" git-commit-file t])
    ("Diff Current Buffer against"
      ["HEAD" git-diff-head t]
      ["Index" git-diff-index t]
      ["Upstream" git-diff-upstream t]
      ["Other..." git-diff-other t]
      )
    ("Diff Repository against"
     ["HEAD" git-diff-all-head t]
     ["Index" git-diff-all-index t]
     ["Upstream" git-diff-all-upstream t]
     ["Other..." git-diff-all-other t])
    "---"
    ["Log for Entire Project" git-log t]
    ["Log for Current File" git-log-files t]
    ["Log for Branch or Tag..." git-log-other t]
    ["Find Lost Commits with Reflog..." git-log-dontpanic-reflog t]
    "---"
    ["Merge (start or continue)..." git-merge-next-action t]
    ["Reset to..." git-reset t]
    ["Stash..." git-stash t]
    ["Rename file..." git-rename t]
    "---"
    ["Pull from Remote..." git-pull t]
    ["Push to Remote..." git-push t]
    "---"
    ["Branch View" git-branch t]
    ["Status" git-status t]
    ["Grep..." git-grep t]
    ["Git Command..." git-cmd t])
  "vc")
;; Eval below to start over (then eval-buffer).
;; (makunbound 'git-global-map)



(provide 'git-global-keys)
