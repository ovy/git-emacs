;; Git log mode support, part of git-emacs
;;
;; See git-emacs.el for license information

(require 'log-view)
(require 'git-emacs)

;; Based off of log-view-mode, which has some nice functionality, like
;; moving between commits. It's also based on a different model than git,
;; so we have to undo some things.
(define-derived-mode git-log-view-mode
  log-view-mode "Git-Log" "Major mode for viewing git logs"
  :group 'git
  ;; Customize log-view-message-re to be the git commits
  (set (make-local-variable 'log-view-message-re)
       "^[Cc]ommit[: ]*\\([0-9a-f]+\\)")
  ;; As for the file re, there is no such thing -- make it impossible
  (set (make-local-variable 'log-view-file-re)
       "^No_such_text_really$")
  (set (make-local-variable 'font-lock-defaults)
       (list 'git-log-view-font-lock-keywords t))
  (set (make-local-variable 'transient-mark-mode) t)

  ;; A long git log might still be running when we die. Avoid "deleted buffer".
  (add-hook 'kill-buffer-hook
            #'(lambda()
                (let ((proc (get-buffer-process (current-buffer))))
                  (when proc (delete-process proc))))
            nil t)                      ; prepend, local
  )


;; Highlighting. We could allow customizable faces, but that's a little
;; much right now.
(defvar git-log-view-font-lock-keywords
  '(("^\\([Cc]ommit\\|[Mm]erge\\):?\\(.*\\)$"
     (1 font-lock-keyword-face prepend)
     (2 font-lock-function-name-face prepend))
    ("^\\(Author\\):?\\(.*?\\([^<( \t]+@[^>) \t]+\\).*\\)$"
     (1 font-lock-keyword-face prepend) (2 font-lock-constant-face prepend)
     (3 font-lock-variable-name-face prepend))
    ("^\\(Date\\):?\\(.*\\)$"
     (1 font-lock-keyword-face prepend) (2 font-lock-doc-face prepend))
    )
  "Font lock expressions for git log view mode")
;; (makunbound 'git-log-view-font-lock-keywords)  ; <-- C-x C-e to reset


;; Keys
(let ((map git-log-view-mode-map))
  (define-key map "N" 'git-log-view-interesting-commit-next)
  (define-key map "P" 'git-log-view-interesting-commit-prev)

  (define-key map "m" 'set-mark-command) ; came with log-view-mode, nice idea
  (define-key map "d" 'git-log-view-diff-preceding)
  (define-key map "=" 'git-log-view-diff-preceding) ; a log-view mode key
  (define-key map "D" 'git-log-view-diff-current)
  
  (define-key map "c" 'git-log-view-cherry-pick)
  (define-key map "k" 'git-log-view-checkout)
  (define-key map "r" 'git-log-view-reset)
  (define-key map "v" 'git-log-view-revert)
  (define-key map "t" 'git-log-view-tag)
  (define-key map "b" 'git-log-view-branch)

  (define-key map "f" 'git-log-view-visit-file)

  (define-key map "l" 'git-log-other)
  (define-key map "L" 'git-log-view-apply-custom)
  (define-key map "S" 'git-log-dontpanic-reflog)
  (define-key map "g" 'git-log-view-refresh)
  (define-key map "q" 'git--quit-buffer)
  ;; Suppress the log-view menu. Many items are broken beyond repair when
  ;; applied to git.
  (define-key map [menu-bar Log-View] 'undefined)
  )


;; Menu
(easy-menu-define
 git-log-view-menu git-log-view-mode-map
 "Git"
 `("Git-Log"
   ;; With log-view's key alternatives, menu sometimes picks wrong ones.
   ["Next Commit" log-view-msg-next :keys "n"]
   ["Previous Commit" log-view-msg-prev :keys "p"]
   ["Next Interesting Commit" git-log-view-interesting-commit-next t]
   ["Previous Interesting Commit" git-log-view-interesting-commit-prev t]
   "---"
   ["Mark Commits for Diff" set-mark-command :keys "m"]
   ["Diff Commit(s)" git-log-view-diff-preceding :keys "d"]
   ["Diff against Current" git-log-view-diff-current t]
   "---"
   ["Reset Branch to Commit" git-log-view-reset t]
   ["Checkout" git-log-view-checkout t]
   ["Cherry-pick" git-log-view-cherry-pick t]
   ["Revert Commit" git-log-view-revert t]
   ["Tag this Commit..." git-log-view-tag t]
   ["Branch from this Commit..." git-log-view-branch t]
   "---"
   ["Visit File at this Commit" git-log-view-visit-file t]
   "---"
   ["Open Another Log..." git-log-other t]
   ["Apply Log Options..." git-log-view-apply-custom t]
   ["Find Lost Commits with Reflog..." git-log-dontpanic-reflog t]
   ["Refresh" git-log-view-refresh t]
   ["Quit" git--quit-buffer t]))
;; Eval below to start over (then eval-buffer).
;; (makunbound 'git-log-view-mode-map)


;; Extra navigation
;; Right now this just moves between merges, but it would be nice to move
;; to the next/prev commit by a different author. But it's harder than a
;; simple RE.
(defvar git-log-view-interesting-commit-re
  "^Merge[: ]?\\|^ *This reverts commit \\|^[Cc]ommit [[:xdigit:]]+ ("
  "Regular expression defining \"interesting commits\" for easy navigation")
(easy-mmode-define-navigation
 git-log-view-interesting-commit git-log-view-interesting-commit-re
 "interesting commit")
;; (makunbound 'git-log-view-interesting-commit-re)


;; Implementation
(defvar git-log-view-filenames nil
  "List of filenames that this log is about, nil if the whole repository.")
(defvar git-log-view-qualifier nil
  "A short string representation of `git-log-view-filenames', e.g. \"2 files\"")
(defvar git-log-view-start-commit nil
  "Records the starting commit (e.g. branch name) of the current log view.
Note that this is a logical 'start' as opposed to a fully fixed commit,
so a refresh picks up a new state of the branch or tag, if changed.
See `git-log-view-displayed-commit-id'")
(defvar git-log-view-displayed-commit-id nil
  "Records the starting point of the history that is *actually* displayed.
If branch has moved since, `git-log-view-start-commit' would track with it,
which might be misleading. A refresh operation briefly displays this, for
example, to allow the user to go back to the old history. This should be
a full id.")

(defvar git-log-view-before-log-hooks nil
  "Hooks to run in `git-log-view-mode' just before the log is
actually inserted. May explicitly modify variables like
`git-log-view-start-commit', `git-log-view-displayed-commit-id',
set keys, insert text, etc.")


(defcustom git-log-view-additional-log-options nil
  "Additional command-line flags for 'git log' when run in `git-log-view-mode'.
For example, '(\"--decorate\" \"--abbrev-commit\")."
  :type '(repeat string)
  :options '("--decorate" "--abbrev-commit") ; only suggestions.
  :group 'git-emacs
  :risky t
  )


(defvar git-log-view-custom-options nil
  "Arguments (git log switches) to set programmatically in a
`git-log-view-mode' buffer. Becomes buffer-local after buffer
creation. It's a good idea to set a custom buffer name as well")


(defun git--log-view (&optional files start-commit dont-pop-buffer
                                use-buffer)
  "Show a log window for the given FILES; if none, the whole
repository. If START-COMMIT is nil, use the current branch,
otherwise the given commit. DONT-POP-BUFFER should be set to t if
the caller will do the displaying themselves. USE-BUFFER means to
use an existing buffer; pass a string to leave the name
unchanged, or a buffer to have log-view change it.

Assumes it is being run from a buffer whose default-directory is
inside the repo."

 (let* ((rel-filenames (mapcar #'file-relative-name files))
         (log-qualifier (case (length files)
                               (0 (abbreviate-file-name (git--get-top-dir)))
                               (1 (first rel-filenames))
                               (t (format "%d files" (length files)))))
         (log-buffer-name (format "*git log: %s%s*"
                                  log-qualifier
                                  (if start-commit (format " from %s"
                                                           start-commit)
                                    "")))
         (buffer (get-buffer-create (or use-buffer log-buffer-name)))
         (saved-default-directory default-directory))
   (with-current-buffer buffer
     (when (bufferp use-buffer) (rename-buffer log-buffer-name))
      ;; Subtle: a previous git process might still be running
      (let ((proc (get-buffer-process (current-buffer))))
        (when proc (delete-process proc)))
      (git-log-view-mode)
      (buffer-disable-undo)
                                        
      ;; Tell git-log-view-refresh what this log is all about
      (set (make-local-variable 'git-log-view-qualifier) log-qualifier)
      (set (make-local-variable 'git-log-view-start-commit) start-commit)
      (set (make-local-variable 'git-log-view-displayed-commit-id) nil)
      (set (make-local-variable 'git-log-view-filenames) rel-filenames)
      (make-local-variable 'git-log-view-custom-options)
      ;; Let base log-view mode know if we're taking about different files
      (set (make-local-variable 'log-view-per-file-logs) nil)
      (set (make-local-variable 'log-view-vc-fileset)
           ;; The two empty strings hack may look disgusting, but it makes
           ;; log-view behave right; in particular refusing to do file
           ;; operations. In my defense, that's very antiquated code.
           (or files '("" "")))

      ;; Subtle: the buffer may already exist and have the wrong directory
      (cd saved-default-directory)
      (git-log-view-refresh))
   (if dont-pop-buffer
       buffer
     (pop-to-buffer buffer))))

(defun git-log-view-refresh (&optional is-explicit-refresh)
  "Refreshes a git-log buffer. If called interactively or
IS-EXPLICIT-REFRESH is set, assumes the user requested it directly."
  (interactive "p")
  (let ((buffer-read-only nil)) (erase-buffer))
  (run-hooks 'git-log-view-before-log-hooks)
  (let* ((the-start-commit git-log-view-start-commit)
         (new-commit-id (git--rev-parse (or the-start-commit "HEAD"))))
    ;; Allow recovery from refresh "accidents" during branch surgery.
    (when (and git-log-view-displayed-commit-id is-explicit-refresh
               (not (equal git-log-view-displayed-commit-id new-commit-id)))
      (message "You can recover the previously displayed log as '%s'"
               (git--abbrev-commit git-log-view-displayed-commit-id)))
    (setq git-log-view-displayed-commit-id new-commit-id)
    ;; vc-do-command does almost everything right. Beware, it misbehaves
    ;; if not called with current buffer (undoes our setup)
    (apply #'vc-do-command (current-buffer) 'async "git" nil "log"
           (append git-log-view-additional-log-options
                   git-log-view-custom-options
                   (list new-commit-id) (list "--") git-log-view-filenames))
    )
  
  ;; vc sometimes goes to the end of the buffer, for unknown reasons
  (vc-exec-after `(goto-char (point-min))))


(defun git-log-view-single-file-p ()
  "Returns true if the current git-log buffer is for a single file"
  (when (boundp 'git-log-view-filenames)
    (= 1 (length git-log-view-filenames))))

;; Entry points
(defun git-log-files ()
  "Launch the git log view for the current file, or the selected files in
git-status-mode."
  (interactive)
  (git--require-buffer-in-git)
  (git--log-view (git--if-in-status-mode
                     (git--status-view-marked-or-file)
                   (list buffer-file-name))))
 
(defun git-log ()
  "Launch the git log view for the whole repository. If called in a
branch list buffer, log for the branch selected there instead of HEAD."
  (interactive)
  (git--log-view nil (git-branch-mode-selected t)))

(defun git-log-other (&optional commit)
  "Launch the git log view for another COMMIT, which is prompted for if
unspecified. You can then cherrypick commits from e.g. another branch
using the `git-log-view-cherrypick'."
  (interactive (list (git--select-revision "View log for: ")))
  (git--log-view nil commit))


;; Take advantage of the nice git-log-view from the command line.
;; Recipes:
;; function gl() { gnuclient --batch --eval "(git-log-from-cmdline \"$DISPLAY\" \"$(pwd)\" \"$1\")"; }
;; or substitute "emacsclient -e" for "gnuclient --batch"
;;
;; If you prefer a separate emacs instance:
;; function gl() { emacs -l ~/.emacs --eval "(git-log-from-cmdline nil nil \"$1\")"; }
;;
;; Then you can just run "gl" or "gl another-branch", for example.
(defun git-log-from-cmdline (&optional display directory start-commit)
  "Launch a git log view from emacs --eval or gnuclient
--eval. If DISPLAY is specified, create a frame on the specified
display; "" means current. If DIRECTORY is specified, do git log
for that directory (a good idea in gnuclient) . If START-COMMIT
if specified, log starting backwards from that commit, e.g.  a
branch."
  (let ((default-directory (or directory default-directory))
        (frame (when display
                 (select-frame
                  (make-frame-on-display
                   (unless (string= display "") display))))))
    (when frame (x-focus-frame frame))
    (switch-to-buffer
     (git--log-view nil (when (> (length start-commit) 0) start-commit) t))
    (when frame
      ;; Delete the frame on quit if we created it and nothing else displayed
      (add-hook 'kill-buffer-hook
              (lexical-let ((git-log-gnuserv-frame frame))
                #'(lambda()
                    (dolist (window (get-buffer-window-list (current-buffer)))
                      (when (and (one-window-p t)
                                 (eq (window-frame window)
                                     git-log-gnuserv-frame))
                          (delete-frame (window-frame window))))))
              t t))                      ; hook is append, local
  (buffer-name)))   ;; emacsclient prints this

;; Actions
(defun git-log-view-checkout ()
  "Checkout the commit that the mark is currently in."
  (interactive)
  (let ((commit (substring-no-properties (log-view-current-tag))))
    (when (y-or-n-p (format "Checkout %s from %s? "
                            git-log-view-qualifier commit))
      (if git-log-view-filenames
          (progn
            (apply #'git--exec-string "checkout" commit "--"
                   git-log-view-filenames)
            (git-after-working-dir-change git-log-view-filenames))
        (git-checkout commit)))))     ;special handling for whole-tree checkout

(defun git-log-view-cherry-pick ()
  "Cherry-pick the commit that the cursor is currently in on top of the current
branch."
  (interactive)
  (let ((commit (substring-no-properties (log-view-current-tag)))
        (current-branch (git--current-branch)))
    (when (y-or-n-p (format "Cherry-pick commit %s on top of %s? "
                            commit (git--bold-face current-branch)))
      (git--exec-string "cherry-pick" commit "--")
      (git-after-working-dir-change))))

(defun git-log-view-reset ()
  "Reset the current branch to the commit that the cursor is currently in."
  (interactive)
  (let ((commit (substring-no-properties (log-view-current-tag)))
        (current-branch (ignore-errors (git--current-branch))))
    (when (y-or-n-p (format "Reset %s to commit %s? "
                            (if current-branch (git--bold-face current-branch)
                              "current state")
                            (git--abbrev-commit commit)))
      (git-reset commit))))

(defun git-log-view-diff-preceding ()
  "Diff the commit the cursor is currently on against the preceding commits.
If a region is active, diff the first and last commits in the region."
  (interactive)
  (let* ((commit (git--abbrev-commit
                 (log-view-current-tag (when mark-active (region-beginning)))))
        (preceding-commit
         (git--abbrev-commit
          (save-excursion
            (when mark-active
              (goto-char (region-end))
              ;; Go back one to get before the lowest commit, then
              ;; msg-next will find it properly. Unless the region is empty.
              (unless (equal (region-beginning) (region-end))
                (backward-char 1)))
            (log-view-msg-next)
            (log-view-current-tag)))))
    ;; TODO: ediff if single file, but git--ediff does not allow revisions
    ;; for both files
    (git--diff-many git-log-view-filenames preceding-commit commit t)))

(defun git-log-view-diff-current ()
  "Diff the commit the cursor is currently on against the current state of
the working dir."
  (interactive)
  (let* ((commit (git--abbrev-commit (log-view-current-tag))))
    (if (git-log-view-single-file-p)
        (git--diff (first git-log-view-filenames)
                   (concat commit ":" ))
      (git--diff-many git-log-view-filenames commit nil))))

(defun git-log-view-revert ()
  "Revert the commit that the cursor is currently on"
  (interactive)
  (let ((commit (substring-no-properties (log-view-current-tag))))
    (when (y-or-n-p (format "Revert %s? " commit))
      (git-revert commit))))


(defun git-log-view-tag (&optional tag-name)
  "Create a new tag for commit that the cursor is on."
  (interactive)
  (git-tag tag-name (git--abbrev-commit (log-view-current-tag))))


(defun git-log-view-branch (&optional branch)
  "Pops up the git-branch buffer and prompts for a branch starting at
the current `git-log-view-mode' commit. Does not check it out, but
leaves cursor on it."
  (interactive)
  (let ((current-tag (log-view-current-tag))) ;; before we switch buffers
    (git-branch)
    (redisplay t)
    (git-new-branch branch current-tag)))


(defun git--log-view-need-filename (prompt &optional allow-nonexisting)
  "If this view is not for a single file, prompt for one with PROMPT.
Set ALLOW-NONEXISTING if the file could be from a different revision, no longer
existing in current tree."
  (if (git-log-view-single-file-p)
      (elt git-log-view-filenames 0)
    (read-file-name prompt nil nil (not allow-nonexisting) ""
                    #'(lambda (fn) (> (length fn) 0)))))


(defun git-log-view-visit-file (&optional filename commit)
  "Visits a file from the commit that the cursor is on in
`view-mode'. If this view is not for a single file, prompts for
one, autocompleting from the checked out tree but not requiring
an existing file in case it no longer exists in the current
version. Non-interactively, the parameters FILENAME and COMMIT
are self-explanatory strings. "
  (interactive
   (let ((short-commit (git--abbrev-commit (log-view-current-tag))))
     (list (git--log-view-need-filename (format "File @ %s: " short-commit) t)
           short-commit)))
  ;; vc-find-revision is retarded: it *actually* creates a file!
  (let* ((default-directory (or (file-name-directory filename)
                                default-directory))
         (base-filerev (concat commit ":" (file-name-nondirectory filename)))
         (full-filerev (concat commit ":" (file-relative-name
                                        filename (git--get-top-dir)))))
    (view-buffer (git--cat-file base-filerev filename "blob" full-filerev)
                 'kill-buffer-if-not-modified)))


(defvar-local git-log-reflog-lines nil "Data for reflog buffers (vector)")
(defvar-local git-log-reflog-i nil "Current position of a reflog buffer.")
(defvar git-log-reflog-lines-setup nil "Used temporarily during reflog setup.")

(defun git-log-dontpanic-reflog (&optional states-of)
  "Pulls up a specialized log view for walking the reflog to
find lost or endangered commits. Prompts for a branch name or
similar to track (STATES-OF), allowing \"*all*\" as an option to
track everything known to reflog (i.e. recent repo changes)."
  (interactive
   (list (git--select-revision
          "Find recent states of:" '("HEAD" "*all*"))))
  (let* ((default-directory (git--get-top-dir-or-prompt "Which repository: "))
         (scope (if (or (null states-of) (string= states-of "*all*")) "--all"
                  states-of))
         (reflog-lines
          (split-string
           (git--exec-string "reflog" "--pretty=format:%H\t%gd\t%gs" scope)
           "\n" t))
         (buffer-name
          (format "git reflog: %s for %s" 
                  (abbreviate-file-name default-directory)
                  (if (string= "--all" scope) "all refs" scope)))
         (git-log-view-mode-hook git-log-view-mode-hook)       ; save
         (git-log-reflog-lines-setup (vconcat reflog-lines)))
    (unless reflog-lines
      (error "\"git reflog\" returned nothing. Try command line%s."
             (if (string= "--all" scope) "" " or *all*")))
    (add-hook 'git-log-view-mode-hook 'git--log-reflog-setup)
    (git--log-view nil nil nil buffer-name)))

  
(defun git--log-reflog-setup ()
  (set (make-local-variable 'git-log-reflog-lines) git-log-reflog-lines-setup)
  (set (make-local-variable 'git-log-reflog-i) 0)
  (let ((map (make-sparse-keymap))) ;; because LOCAL-set-key isn't.
    (define-key map "\M-n" 'git-log-reflog-next)
    (define-key map "\M-p" 'git-log-reflog-prev)
    (set-keymap-parent map git-log-view-mode-map)
    (use-local-map map))
  (font-lock-add-keywords
   nil '(("^#[^\n]*" . font-lock-doc-face)
         ("^# Use " "\\[.+?\\]" nil nil (0 font-lock-constant-face t))
         ("^# (\\([[:digit:]/]+\\)[^\n]+ \\(as\\|of\\|is\\) "
          (1 font-lock-constant-face t)
          ("NOT [[:upper:] ]+" nil nil (0 font-lock-warning-face t))
          ("\\(tag: \\)?\\([^,.]+\\)"
           nil nil (2 font-lock-function-name-face t)))
         ("^#   \\([-[:lower:]() ]+\\):" 1 font-lock-variable-name-face t)))
  ;; Add buffer-local hook to do the actual work.
  (add-hook 'git-log-view-before-log-hooks 'git--log-reflog-refresh t t))


(defun git--log-reflog-refresh ()
  (let ((buffer-read-only nil))
    (insert "# In this specialized log view, you can find and recover recent "
            "git states.\n")
    (insert (format "# Use [%s] and [%s] to switch trees"
                    (substitute-command-keys "\\[git-log-reflog-next]")
                    (substitute-command-keys "\\[git-log-reflog-prev]"))
            ", then checkout/reset/tag/etc (see menu).\n\n")
    (let* ((reflog-line (elt git-log-reflog-lines git-log-reflog-i))
           (split-reflog-line (split-string reflog-line "\t" t))
           (commit (elt split-reflog-line 0))
           (reflog-ref (or (elt split-reflog-line 1) ""))
           (reflog-msg (or (elt split-reflog-line 2) ""))
              ;; See how easy it is to get to it.
           (access-doc
            (or (when (string-match-p "stash@" reflog-ref)
                  (format "stashed as %s" reflog-ref)) ; stash safe, if seen
                (let ((desc (git--log "--max-count=1" "--pretty=format:%D"
                                      commit)))
                  (when (> (length desc) 0) (format "accessible as %s" desc)))
                (ignore-errors
                  (format "an ancestor of %s"
                          (car (split-string
                                (git--describe commit "--all" "--contains")
                                "[\\^~]+" t))))
                
                "NOT EASILY ACCESSIBLE"))) ;; Bingo
      (insert (format "# (%d/%d) This tree is %s.\n"
                      (+ 1 git-log-reflog-i) (length git-log-reflog-lines)
                      access-doc))
      (insert "#   " reflog-msg)
      (insert "\n\n")
      (setq git-log-view-start-commit commit)
      )))

(defun git-log-reflog-next ()
  (interactive)
  (setq git-log-reflog-i (mod (+ git-log-reflog-i 1)
                              (length git-log-reflog-lines)))
  (git-log-view-refresh))
           
(defun git-log-reflog-prev ()
  (interactive)
  (setq git-log-reflog-i (mod (- git-log-reflog-i  1)
                              (length git-log-reflog-lines)))
  (git-log-view-refresh))


;; A way to refresh log view with custom options. Most useful for finding stuff.
(defvar git-log-view-custom-history '("-G^int main\(") ; as example, with space
  "History variable for `git-log-view-apply-custom'")

(defun git-log-view-apply-custom ()
  "Prompt and apply a custom set of 'git log' options to this log view.
This is most useful to use git's search options, like -G<regexp>. Some
formatting options will probably cause log view navigation to stop working.
Arguments are requested one by one and should not be shell-quoted.
The custom options are \"sticky\" in this buffer (w.r.t. refresh), so
this function adds \"<custom>\" to the buffer name to avoid confusion."
  (interactive)
  (unless (eq major-mode 'git-log-view-mode) (error "Not in git log view"))
  (setq-local
   git-log-view-custom-options
   (loop for i from 1 to 1000
         with one-arg = nil
         do (setq one-arg
                  (read-string (format "git log --arg%d (empty if done): " i)
                               (elt git-log-view-custom-options (- i 1))
                               'git-log-view-custom-history))
         until (string= one-arg "")
         collect one-arg))
  (unless (string-match-p "<custom>" (buffer-name))
    (rename-buffer (concat (buffer-name) " <custom>") t))
  (git--please-wait (format "Refreshing with git log %s"
                            (git--join git-log-view-custom-options))
    (git-log-view-refresh)))
 

(provide 'git-log)
