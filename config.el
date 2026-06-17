;;; config.el --- tangled from config.org -*- lexical-binding: t; -*-

(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
;; Allow upgrading built-in packages from ELPA (needed for transient/Magit etc.)
(setq package-install-upgrade-built-in t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t
      use-package-expand-minimally t)

(define-key global-map (kbd "M-m") mode-specific-map)
(define-key global-map (kbd "M-o") ctl-x-map)

;; RULE: never bind mode-local keys under "C-c ..." anywhere in this config
;; after this point — always bind them under "M-m ..." directly. A late
;; (define-key some-mode-map (kbd "C-c x") …) would recreate a local C-c
;; prefix and confuse the remapping in the CUA section.

;; The two mechanism helpers live up here ON PURPOSE: packages that load
;; during init (dirvish pulls in dired, which pulls in wdired) run
;; `with-eval-after-load' blocks that call them immediately.

(defun my/mirror-c-to-m (keymap)
  "Add M-<key> bindings for every C-<key> binding in KEYMAP."
  (map-keymap
   (lambda (key def)
     (when (and (integerp key) (>= key ?\C-a) (<= key ?\C-z)
                (not (memq key '(?\C-g ?\C-h ?\C-i ?\C-j ?\C-m))))
       (let ((m-key (+ (- key ?\C-a) ?\M-a)))
         (unless (lookup-key keymap (vector m-key))
           ;; Skip keys that can't be mirrored: M-<k> is stored as ESC <k>,
           ;; which clashes when the map binds ESC itself to a command
           ;; (wdired does, for example).
           (ignore-errors
             (define-key keymap (vector m-key) def))))))
   keymap))

(defun my/minor-cua-fix (map)
  "Move MAP's C-c prefix bindings under M-m and free C-c.
MAP is a minor-mode keymap. Its C-c submap is mirrored (C-<k> -> M-<k>)
and exposed at M-m; sequences not in the submap fall through to the
major-mode and global leader maps."
  (let ((cc (lookup-key map (kbd "C-c"))))
    (when (keymapp cc)
      ;; If the submap binds ESC directly to a command (wdired: C-c ESC =
      ;; abort), every M-<k> mirror would clash with it, because Emacs
      ;; stores M-<k> as ESC <k>. The binding always duplicates C-c C-k,
      ;; so drop it before mirroring:
      (let ((esc (lookup-key cc (kbd "ESC"))))
        (when (and esc (not (keymapp esc)))
          (define-key cc (kbd "ESC") nil)))
      (my/mirror-c-to-m cc)
      (define-key map (kbd "M-m") cc)
      (define-key map (kbd "C-c") nil))))

;; Auf Windows nutzt Emacs sonst die System-Codepage (z. B. cp1252).
;; Diese Zeilen erzwingen UTF-8 für Dateien, Terminal, Clipboard, Prozesse.
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(setq locale-coding-system 'utf-8
      default-process-coding-system '(utf-8-unix . utf-8-unix))
;; Neue Dateien standardmäßig mit Unix-Zeilenenden und UTF-8 ohne BOM:
(setq-default buffer-file-coding-system 'utf-8-unix)
;; Windows-spezifisch:
;;   - Dateinamen mit Umlauten korrekt in Modeline/Buffername anzeigen
;;     → `file-name-coding-system' explizit setzen (DIE wird tatsächlich
;;       benutzt; `default-file-name-coding-system' ist nur der Fallback).
;;   - `w32-unicode-filenames' weist Emacs an, die Wide-API von Windows
;;     zu nutzen statt der ANSI-Codepage. Damit funktionieren auch Pfade
;;     außerhalb von cp1252 (Kyrillisch, CJK, Emoji, …).
;;   - `w32-multibyte-process-coding-system' für PowerShell-Aufrufe.
(when (eq system-type 'windows-nt)
  (setq w32-unicode-filenames 'utf-8)
  (setq file-name-coding-system 'utf-8)
  (setq default-file-name-coding-system 'utf-8)
  (setq w32-multibyte-process-coding-system 'utf-8-dos)
  (set-coding-system-priority 'utf-8)
  (defun my/read-reg-path (key)
    (with-temp-buffer
      (when (zerop (call-process "reg" nil t nil "query" key "/v" "Path"))
        (goto-char (point-min))
        (when (re-search-forward "REG_\\(?:EXPAND_\\)?SZ\\s-+" nil t)
          (string-trim (buffer-substring (point) (line-end-position)))))))
  (let* ((user-path (or (my/read-reg-path "HKCU\\Environment") ""))
         (sys-raw  (or (my/read-reg-path
                        "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment") ""))
         (sys-path (replace-regexp-in-string
                    "%\\([^%]+\\)%"
                    (lambda (m) (or (getenv m) m))
                    sys-raw))
         (full     (concat user-path ";" sys-path)))
    (setenv "PATH" full)
    (setq exec-path (append (parse-colon-path full) (list exec-directory)))))

(setq inhibit-startup-message t
      initial-scratch-message nil
      ring-bell-function 'ignore
      use-short-answers t
      create-lockfiles nil
      make-backup-files nil
      auto-save-default nil
      custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file))

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)
(delete-selection-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(setq recentf-max-saved-items 500)

;; Nerd font. Tries a list of common Nerd Font names and picks the first one
;; that's actually installed. Add/reorder to taste.
(defvar my/font-candidates
  '("Cascadia Mono"
    "JetBrainsMono Nerd Font"
    "JetBrainsMonoNL Nerd Font"
    "JetBrainsMono NF"            ;; common Windows variant
    "FiraCode Nerd Font"
    "Hack Nerd Font"
    "Iosevka Nerd Font"))
(defvar my/font-size 130) ;; 1/10 pt — bump to 140/150 if you want it bigger

(defun my/set-font ()
  "Pick the first available font from `my/font-candidates'."
  (let ((available (font-family-list)))
    (catch 'done
      (dolist (f my/font-candidates)
        (when (member f available)
          (set-face-attribute 'default     nil :family f :height my/font-size)
          (set-face-attribute 'fixed-pitch nil :family f :height my/font-size)
          (message "Using font: %s" f)
          (throw 'done f))))))

(my/set-font)
;; Re-apply for new frames (daemon / emacsclient):
(add-hook 'server-after-make-frame-hook #'my/set-font)

;; Dark:  doom-dark+      — port of VS Code's Dark+ (somber, desaturated)
;; Light: doom-one-light  — clean, Office-like
;; M-m T toggles between them; the choice persists across restarts.
;; (doom-gruvbox stays installed — add it to `my/themes' to cycle it too.
;;  Built-in `modus-operandi' is another very professional light option.)
(defvar my/themes '(doom-dark+ doom-one-light)
  "Themes `my/theme-toggle' cycles through. First entry is the default.")
(defvar my/theme-file (expand-file-name "current-theme" user-emacs-directory)
  "File remembering the last active theme between sessions.")

(defun my/load-theme (theme)
  "Load THEME exclusively and remember it for the next session."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t)
  (with-temp-file my/theme-file (insert (symbol-name theme))))

(defun my/theme-toggle ()
  "Cycle through `my/themes' (dark <-> light)."
  (interactive)
  (let* ((cur (car custom-enabled-themes))
         (next (or (cadr (memq cur my/themes)) (car my/themes))))
    (my/load-theme next)
    (message "Theme: %s" next)))

(defun my/saved-theme ()
  "Return the saved theme symbol, or the default (car of `my/themes')."
  (or (and (file-exists-p my/theme-file)
           (intern (string-trim
                    (with-temp-buffer
                      (insert-file-contents my/theme-file)
                      (buffer-string)))))
      (car my/themes)))

(defun my/apply-saved-theme (&optional frame)
  "Apply the saved theme — on FRAME if given (for daemon client frames)."
  (condition-case nil
      (let ((theme (my/saved-theme)))
        (if frame
            (with-selected-frame frame
              (when (display-graphic-p)
                (my/load-theme theme)))
          (my/load-theme theme)))
    (error (my/load-theme (car my/themes)))))

(defun my/apply-theme-on-first-gui-frame (frame)
  "Daemon only: apply the saved theme on the first GUI frame, then quit."
  (when (and (daemonp) (frame-live-p frame) (display-graphic-p frame))
    (my/apply-saved-theme frame)
    (remove-hook 'after-make-frame-functions
                 #'my/apply-theme-on-first-gui-frame)))

(use-package doom-themes
  :demand t   ; :bind would otherwise DEFER loading — without this, the
              ; :config below never runs at startup, so NO theme loads
              ; until M-m T is pressed (startup looks unstyled).
  :custom
  (doom-themes-enable-bold t)
  (doom-themes-enable-italic t)
  :bind (("M-m T" . my/theme-toggle))
  :config
  (doom-themes-org-config)
  ;; Non-daemon: a GUI frame already exists, so apply now. Daemon: there
  ;; is no GUI frame at init, so apply on the first client frame instead.
  (if (daemonp)
      (add-hook 'after-make-frame-functions #'my/apply-theme-on-first-gui-frame)
    (my/apply-saved-theme)))

;; Optional: a clean modeline that pairs well with doom-themes and shows
;; nerd-icons. Comment out if you prefer the vanilla modeline.
(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :custom
  (doom-modeline-height 28)
  (doom-modeline-icon t))

;; Icons (uses your installed Nerd Font)
(use-package nerd-icons)
(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (advice-add 'nerd-icons-completion-affixate :around
    (lambda (orig &rest args)
      (condition-case nil
          (apply orig args)
        (error (mapcar (lambda (c) (if (stringp c) (list c "" "") c))
                       (car args)))))))
;; Note: don't enable `nerd-icons-dired' — dirvish already draws icons via
;; its `nerd-icons' attribute, and the two together produce duplicates.

(use-package which-key
  :config
  (which-key-mode 1)
  ;; Group labels for the leader prefixes (general.el used to provide these):
  (which-key-add-key-based-replacements
    "M-m f" "files"
    "M-m n" "notes/roam"
    "M-m d" "download/images"
    "M-m p" "projects"
    "M-m x" "lifecycle"))

(use-package vertico
  :init (vertico-mode)
  :custom
  (vertico-cycle t)
  (vertico-count 15))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Smarter editing of file paths in the minibuffer: Backspace deletes a
;; whole directory component when point is right after a "/", RET enters
;; a directory instead of submitting it.
(use-package vertico-directory
  :ensure nil   ;; ships inside the vertico package
  :after vertico
  :bind (:map vertico-map
              ("RET"   . vertico-directory-enter)
              ("DEL"   . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word)))

(use-package marginalia
  :init (marginalia-mode))

(use-package savehist
  :ensure nil
  :init (savehist-mode))

(use-package consult
  :bind
  ;; Global bindings
  (("M-y"     . consult-yank-pop)
   ("C-f"     . consult-line)            ;; in-buffer search
   ("M-g g"   . consult-goto-line)
   ("M-g i"   . consult-imenu)
   ;; M-m leader (files)
   ("M-m f r" . consult-recent-file)     ;; recent files
   ("M-m f f" . find-file)               ;; plain find-file
   ("M-m f g" . consult-ripgrep)         ;; grep across project
   ("M-m f l" . consult-line)            ;; line search
   ;; M-o leader (C-x style)
   ("M-o b"   . consult-buffer)          ;; switch buffer / recent / bookmark
   ("M-o r b" . consult-bookmark))
  :custom
  (consult-narrow-key "<")
  (consult-async-min-input 2)
  ;; NEVER auto-preview these: openwith would launch the external viewer
  ;; synchronously (PDF freeze!), and binary formats are useless as text.
  (consult-preview-excluded-files
   '("\\.pdf\\'" "\\.mp4\\'" "\\.mkv\\'" "\\.webm\\'" "\\.avi\\'"
     "\\.docx?\\'" "\\.xlsx?\\'" "\\.pptx?\\'" "\\.zip\\'" "\\.7z\\'"
     "\\.exe\\'" "\\.png\\'" "\\.jpe?g\\'" "\\.gif\\'"))
  ;; Files larger than this are previewed as raw text (no org-mode startup,
  ;; no inline images, no fontification) — keeps big org files instant:
  (consult-preview-partial-size 102400)   ;; 100 kB
  (consult-preview-partial-chunk 51200)   ;; show first 50 kB of those
  :config
  ;; File-opening commands: NO automatic preview while scrolling — preview
  ;; only on demand with M-. in the minibuffer; the file itself opens on RET.
  ;; (Buffer switching keeps live preview: buffers are already loaded, cheap.)
  (consult-customize
   consult-recent-file consult-ripgrep consult-dir
   :preview-key "M-."))

(defun my/recent-dirs ()
  "Pick a recent directory from `recentf-list' and open it in dired."
  (interactive)
  (let* ((dirs (seq-filter #'file-directory-p recentf-list))
         (dir (consult--read dirs :sort t :require-match t
                             :prompt "Recent directory: "
                             :category 'file)))
    (when dir (dired dir))))

(use-package consult-dir
  :bind (("M-m f d" . consult-dir)))

(use-package embark
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("<f1> B" . embark-bindings)))

(use-package embark-consult
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;; Editable search results — the interactive project-replace workflow:
;; M-m f g (ripgrep) -> C-. E (embark-export to a grep buffer)
;; -> M-m M-p (make it editable, wgrep) -> edit like normal text,
;; multi-cursor works too -> M-m M-c applies all edits to the files.
(use-package wgrep
  :custom (wgrep-auto-save-buffer t))

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :bind (("M-o M-j" . dired-jump))
  :custom
  (dired-listing-switches "-laGh1v --group-directories-first")
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always)
  (dired-dwim-target t)            ;; copy/move to other dired window by default
  (delete-by-moving-to-trash t)
  :hook ((dired-mode . dired-hide-details-mode)
         (dired-mode . hl-line-mode)))

(use-package dired-subtree
  :after dired
  :bind (:map dired-mode-map
              ("<tab>" . dired-subtree-toggle)
              ("<backtab>" . dired-subtree-cycle)))

;; right, left for dired navigation
(with-eval-after-load 'dired
  (keymap-set dired-mode-map "<right>" #'dired-find-file)
  (keymap-set dired-mode-map "<left>" #'dired-up-directory))

;;   F2          rename inline (wdired: edit names like text, C-s to apply)
;;   C-S-n       new file — or new directory if the name ends with /
;;   C-c/C-x/C-v copy / cut / paste FILES (Explorer-style file clipboard)
;;   C-a         select all (toggle marks)
;;   Delete      delete to trash        S-Delete   delete permanently
;;   Backspace   up one directory       F5         refresh

(defun my/dired-create (name)
  "Create NAME in the current dired directory.
A trailing / creates a directory, anything else an empty file.
Intermediate directories are created as needed."
  (interactive "sNew (end with / for a directory): ")
  (let ((path (expand-file-name name (dired-current-directory))))
    (when (file-exists-p path)
      (user-error "%s already exists" path))
    (if (string-suffix-p "/" name)
        (make-directory path t)
      (make-directory (file-name-directory path) t)
      (write-region "" nil path nil 'silent))
    (revert-buffer)
    (dired-goto-file (directory-file-name path))))

(defun my/dired-delete-permanently ()
  "Delete marked files (or file at point) WITHOUT using the trash."
  (interactive)
  (let ((delete-by-moving-to-trash nil))
    (dired-do-delete)))

;; File clipboard (dired-ranger): C-c remembers the marked files, C-v
;; copies them into the current directory; C-x + C-v moves them instead.
(use-package dired-ranger :after dired)
(defvar my/dired-cut-pending nil)
(defun my/dired-copy-files ()
  "Explorer C-c: put marked files (or file at point) on the file clipboard."
  (interactive)
  (setq my/dired-cut-pending nil)
  (dired-ranger-copy nil))
(defun my/dired-cut-files ()
  "Explorer C-x: like copy, but C-v will MOVE the files."
  (interactive)
  (dired-ranger-copy nil)
  (setq my/dired-cut-pending t)
  (message "Cut — paste with C-v to move"))
(defun my/dired-paste-files ()
  "Explorer C-v: paste the file clipboard into this directory."
  (interactive)
  (if my/dired-cut-pending
      (dired-ranger-move nil)
    (dired-ranger-paste nil))
  (setq my/dired-cut-pending nil))

;; These keys live in a MINOR-mode map, NOT in dired-mode-map. Binding
;; plain C-x/C-c as commands inside dired-mode-map breaks packages that
;; later define sequences under those prefixes there — dired-x (loaded by
;; dirvish) binds C-x M-o and would fail to load, taking the icons and
;; half of dirvish down with it.
(defvar my/dired-cua-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "<f2>")       #'wdired-change-to-wdired-mode)
    (define-key m (kbd "C-S-n")      #'my/dired-create)
    (define-key m (kbd "C-c")        #'my/dired-copy-files)
    (define-key m (kbd "C-x")        #'my/dired-cut-files)
    (define-key m (kbd "C-v")        #'my/dired-paste-files)
    (define-key m (kbd "C-a")        #'dired-toggle-marks)
    (define-key m (kbd "<delete>")   #'dired-do-delete) ;; -> trash
    (define-key m (kbd "S-<delete>") #'my/dired-delete-permanently)
    (define-key m (kbd "DEL")        #'dired-up-directory)
    (define-key m (kbd "<f5>")       #'revert-buffer)
    m))

(define-minor-mode my/dired-cua-mode
  "Explorer-style keys for dired buffers."
  :keymap my/dired-cua-mode-map)

(add-hook 'dired-mode-hook #'my/dired-cua-mode)
(with-eval-after-load 'dired (require 'wdired))

;; wdired (the F2 inline rename) joins the transient-session scheme:
;; C-s / C-RET apply the renames, C-w aborts; C-c copies text again.
(with-eval-after-load 'wdired
  (my/minor-cua-fix wdired-mode-map)
  (define-key wdired-mode-map (kbd "C-s")        #'wdired-finish-edit)
  (define-key wdired-mode-map (kbd "C-<return>") #'wdired-finish-edit)
  (define-key wdired-mode-map (kbd "C-w")        #'wdired-abort-changes)
  ;; While renaming, Backspace/C-c/C-v must edit TEXT again, so the
  ;; Explorer keys pause during wdired and come back afterwards:
  (advice-add 'wdired-change-to-wdired-mode :after
              (lambda (&rest _) (my/dired-cua-mode 0)))
  (advice-add 'wdired-change-to-dired-mode :after
              (lambda (&rest _) (my/dired-cua-mode 1))))

;; Optional, much fancier dired UI. Comment out if you prefer vanilla dired.
(use-package dirvish
  :init (dirvish-override-dired-mode)
  :custom
  (dirvish-attributes '(nerd-icons file-time file-size collapse subtree-state vc-state git-msg))
  (dirvish-mode-line-format '(:left (sort symlink) :right (omit yank index)))
  :bind (("C-b" . dirvish-side)        ;; VS Code: toggle explorer sidebar
         :map dirvish-mode-map
              ("a"   . dirvish-quick-access)
              ("h"   . dirvish-history-jump)
              ("TAB" . dirvish-subtree-toggle)
              ("M-n" . dirvish-history-go-forward)
              ("M-p" . dirvish-history-go-backward)))

(defvar my/org-dir "~/org/")
  (defvar my/org-projects-dir (expand-file-name "projects/" my/org-dir)
    "One org file per project. Agenda source, org-edna deps, gantt export.
  Projects END: a finished/cancelled project file moves WHOLE into
  projects/archive/ (git mv) and disappears from the agenda.")
  (defvar my/org-areas-dir (expand-file-name "areas/" my/org-dir)
    "One org file per ongoing thing: machine, process domain, team.
  Areas never end; only superseded subtrees inside them get archived
  (M-m x a) into areas/archive/.")
  (defvar my/org-notes-dir (expand-file-name "notes/" my/org-dir)
    "Atomic roam notes of every type — the type is a #+filetags entry,
  not a folder: :concept: Zettel (rewrite freely) and :collection:
  items (movies, places, … with TODO lifecycles).")
  (defvar my/org-records-dir (expand-file-name "records/" my/org-dir)
    "ALL typed moment-records: Laborprotokolle, meeting minutes, field
  reports, audits, … One folder for every record type — the type is a
  #+filetags entry set by the capture template, not a directory. Records
  are written once and never edited after their day; they reference
  projects/areas/tasks by ID link only.")

  ;; Create the whole layout up front so captures/agenda/archiving never
  ;; hit ENOENT (org-archive does NOT create missing directories):
  (dolist (d (list my/org-dir my/org-projects-dir my/org-areas-dir
                   my/org-records-dir my/org-notes-dir
                   (expand-file-name "images/" my/org-dir)
                   (expand-file-name "dailies/" my/org-dir)
                   (expand-file-name "archive/" my/org-dir)
                   (expand-file-name "archive/" my/org-projects-dir)
                   (expand-file-name "archive/" my/org-areas-dir)
                    (expand-file-name "archive/" my/org-records-dir)))
    (make-directory d t))

  ;; --- Agenda = every .org under org/, except any archive/ folder ----
  ;; Folders are organizational defaults only; the agenda sees ALL of them
  ;; (records/, dailies/, notes/, projects/, areas/, …). archive/ folders
  ;; stay out so finished/cancelled/superseded items don't clutter the
  ;; todo views. The list is rebuilt before each `org-agenda' call (advice
  ;; in :config below) so a folder you just created shows up immediately.
  (defun my/org-agenda-files ()
    "Return every .org under `org-directory' except files inside an archive/."
    (directory-files-recursively
     org-directory "\\.org\\'" nil
     (lambda (d) (not (equal (file-name-nondirectory
                              (directory-file-name d)) "archive")))))

  (defvar my/org-agenda-auto-refresh t
    "If non-nil, `org-agenda' rebuilds `org-agenda-files' before running.
The per-folder/per-file agenda helpers bind this to nil to keep their
restriction intact.")

  (use-package org
    :ensure nil
    :hook ((org-mode . org-indent-mode)
           (org-mode . visual-line-mode))
    ;; Global org commands via M-m leader. Mode-local commands need NO bindings
    ;; here: the CUA section mirrors all of org's C-c C-<key> bindings to
    ;; M-m M-<key> automatically (M-m M-t = todo, M-m M-s = schedule,
    ;; M-m M-d = deadline, M-m M-c = C-c C-c, M-m M-e = export, M-m M-l = link,
    ;; M-m M-z = add change note, M-m M-o = open link, M-m M-a = attach, ...).
    :bind (("M-m a" . org-agenda)
           ("M-m c" . org-capture))
    :custom
    (org-directory my/org-dir)
    (org-startup-folded 'content)
    (org-hide-emphasis-markers t)
    (org-pretty-entities t)
    (org-ellipsis " ▾")
    (org-src-fontify-natively t)
    (org-src-tab-acts-natively t)
    (org-confirm-babel-evaluate nil)
    (org-startup-with-inline-images t)        ;; show images automatically on open
    (org-image-actual-width '(200))           ;; cap inline image width at 200px
    ;; --- One Round System: states ---------------------------------------
    ;; Row 1 = actionable items (tasks, tickets, yours or delegated).
    ;; Row 2 = stateful artifacts (projects, decisions, documents, processes).
    ;; "!" = silent timestamp into :LOGBOOK: (no prompt).
    ;; Reasons for state changes are written manually via M-m M-z (org-add-note).
    (org-todo-keywords
     '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "DLGT(g)"
                 "|" "DONE(d)" "CANCELLED(c)")
       (sequence "ACTIVE(a)" "ONHOLD(h)"
                 "|" "FINISHED(f)" "SUPERSEDED(s)" "DROPPED(x)")))
    ;; --- One Round System: the log primitive -----------------------------
    ;; One mechanism for everything: a timestamped, author-stamped, reasoned
    ;; entry in :LOGBOOK: at the moment of change. State changes write it
    ;; automatically; content changes get it manually via M-m M-z
    ;; (org-add-note). %u stamps the author — keep `user-login-name'
    ;; consistent with your git identity (or setq it in site-local config).
    (org-log-into-drawer t)
    (org-treat-insert-todo-heading-as-state-change t) ;; creation = 1st event
    (org-log-refile 'time)                            ;; inbox->home is logged
    (org-log-note-headings
     '((done        . "CLOSING NOTE %t by %u")
       (state       . "State %s from %S %t by %u")
       (note        . "Note taken on %t by %u")
       (reschedule  . "Rescheduled from %S on %t by %u")
       (delschedule . "Not scheduled, was %S on %t by %u")
       (redeadline  . "New deadline from %S on %t by %u")
       (deldeadline . "Removed deadline, was %S on %t by %u")
       (refile      . "Refiled on %t by %u")
       (clock-out   . "")))
    ;; --- One Round System: workspace vs. memory --------------------------
    ;; Archived subtrees land in an archive/ subfolder NEXT TO their source
    ;; file, as ordinary .org files stamped with time/origin/final state:
    ;; gone from the agenda (directory entries below are non-recursive),
    ;; still fully visible to consult-ripgrep and the org-roam graph.
    (org-archive-location "archive/%s::")
    (org-archive-subtree-add-inherited-tags t)
    ;; Refile targets for M-x org-refile and the agenda's refile. (The
    ;; org-log-refile note applies to those paths; org-roam-refile — on
    ;; both M-m M-w and M-m C-w, set in :config below — moves to a node
    ;; without writing a log line. CREATED stamps and git cover origin.)
    (org-refile-targets '((org-agenda-files :maxlevel . 3)))
    (org-refile-use-outline-path 'file)
    (org-outline-path-complete-in-steps nil)
     ;; Agenda = the WHOLE workspace. Every folder under org/ is in the
     ;; agenda (records/, dailies/, notes/, projects/, areas/, …) — only
     ;; archive/ folders are skipped (finished/cancelled/superseded items
     ;; don't belong in a todo view). `my/org-agenda-files' (above) builds
     ;; the list; the :config advice rebuilds it before each `org-agenda'
     ;; so newly added folders appear without restarting.
     (org-agenda-files (my/org-agenda-files))
    :config
    ;; Stable IDs: inserting a link interactively creates an ID at the
    ;; target, so links survive refiling and archiving. Captured entries
    ;; get IDs automatically (see my/org-capture-stamp below).
    (require 'org-id)
    (setq org-id-link-to-org-use-id 'create-if-interactive)
    ;; Rebuild the agenda file list before each `org-agenda' so newly
    ;; added folders appear without restarting. The auto-refresh flag is
    ;; let-bound to nil by the per-folder/per-file agenda commands so
    ;; their restriction survives.
    (defun my/org-refresh-agenda-files ()
      (when my/org-agenda-auto-refresh
        (setq org-agenda-files (my/org-agenda-files))))
    (advice-add 'org-agenda :before
                (lambda (&rest _) (my/org-refresh-agenda-files)))
    ;; Refile = MOVE to a node. org-roam-refile replaces org-refile on
    ;; every key that would invoke it (M-m C-w, C-c C-w): pick any node —
    ;; project file, area, heading with ID — via roam completion, and the
    ;; subtree moves there as a child. Plain org-refile stays reachable
    ;; via M-x org-refile and is what the agenda's refile uses.
    (define-key org-mode-map [remap org-refile] #'org-roam-refile)
    ;; org binds org-refile-copy to C-c M-w, which the leader exposes as
    ;; M-m M-w — and the C->M mirror leaves it in place (it never
    ;; overwrites an existing M-<k>). Claim that key for the move too, so
    ;; BOTH M-m M-w and M-m C-w roam-refile. (org-refile-copy, which we
    ;; don't use, stays on M-x.)
    (define-key org-mode-map (kbd "C-c M-w") #'org-roam-refile))

(defvar my/org-state-log-timer nil
  "Idle timer for debounced state logging.")
(defvar my/org-state-log-info nil
  "Pending state change: (marker from-state to-state).")

(defun my/org-log-state-now ()
  "Insert the pending state-change log entry."
  (when-let ((info my/org-state-log-info))
    (cl-destructuring-bind (marker from to) info
      (when (buffer-live-p (marker-buffer marker))
        (with-current-buffer (marker-buffer marker)
          (save-excursion
            (goto-char marker)
            (org-add-log-setup 'state to from 'time))))))
  (setq my/org-state-log-info nil))

(defun my/org-todo-debounced (orig-fun &optional arg)
  "Advice for `org-todo' that debounces logging."
  ;; Cancel any pending log
  (when my/org-state-log-timer
    (cancel-timer my/org-state-log-timer)
    (setq my/org-state-log-timer nil))
  (let ((from (org-get-todo-state))
        (marker (point-marker)))
    ;; Do the state change without logging
    (let ((org-inhibit-logging t))
      (funcall orig-fun arg))
    ;; Queue debounced log
    (let ((to (org-get-todo-state)))
      (when (not (equal from to))
        (setq my/org-state-log-info (list marker from to))
        (setq my/org-state-log-timer
              (run-with-idle-timer 5 nil #'my/org-log-state-now))))))

(advice-add 'org-todo :around #'my/org-todo-debounced)

(defun my/org-agenda-subdir (dir)
  "Run `org-agenda' restricted to the org files under DIR (recursively).
Lets you look at a single project folder (or even roam) without touching
`org-agenda-files' permanently."
  (interactive (list (read-directory-name "Agenda for: " my/org-dir)))
  (let ((org-agenda-files (directory-files-recursively dir "\\.org\\'"))
        (my/org-agenda-auto-refresh nil))
    (if org-agenda-files
        (org-agenda)
      (user-error "No .org files under %s" dir))))

(defun my/org-agenda-this-file ()
  "Run `org-agenda' restricted to the current buffer's file."
  (interactive)
  (unless (and buffer-file-name (derived-mode-p 'org-mode))
    (user-error "Not visiting an org file"))
  (let ((org-agenda-files (list buffer-file-name))
        (my/org-agenda-auto-refresh nil))
    (org-agenda)))

(global-set-key (kbd "M-m p a") #'my/org-agenda-subdir)
(global-set-key (kbd "M-m p f") #'my/org-agenda-this-file)

;; --- Capture targets: every template picks a folder + file under org/ -
;; No capture has a hardcoded home. Each template prompts for a
;; subdirectory of org/ (archive/ excluded) and a file inside it, so where
;; something lands is decided at capture time. The name you type (Projekt,
;; Versuchsbezeichnung) is reused as the #+title via `my/org-capture-name'.

(defun my/org-slug (s)
  "Turn S into a path-safe lowercase slug (Umlaute & Unicode bleiben)."
  (replace-regexp-in-string "[\\/:*?\"<>|[:space:]]+" "_" (downcase s)))

(defun my/org-pick-dir (&optional default)
  "Completing-read a subdirectory of `org-directory' (archive/ excluded).
Includes org/ itself. DEFAULT (a dir under org/) is offered as the default."
  (let* ((root (expand-file-name org-directory))
         (def  (when default (expand-file-name default)))
         (dirs (cons root
                     (directory-files-recursively
                      root ".*" t
                      (lambda (d) (not (equal (file-name-nondirectory
                                               (directory-file-name d)) "archive"))))))
         (dirs (delete-dups
                (mapcar (lambda (d) (expand-file-name (file-name-as-directory d)))
                        (seq-filter #'file-directory-p dirs)))))
    (expand-file-name
     (completing-read "Verzeichnis: " dirs nil nil nil nil def))))

(defun my/org-pick-file-in (dir)
  "Pick an existing .org file in DIR, or type a new name to create one.
Returns the absolute path; appends .org when the typed name lacks it."
  (let* ((existing (mapcar #'file-name-nondirectory
                           (directory-files dir nil "\\.org\\'")))
         (choice (completing-read "Datei (neu = eintippen): " existing nil nil)))
    (when (or (null choice) (string-empty-p choice))
      (user-error "Kein Dateiname"))
    (let ((name (if (string-suffix-p ".org" choice) choice (concat choice ".org"))))
      (expand-file-name name dir))))

(defvar my/org-capture-name nil
  "Name typed while picking a file-creating target — reused for #+title.")
(defun my/org-capture-title ()
  "Return `my/org-capture-name' for use in %(...) capture expansions."
  (or my/org-capture-name ""))

(defun my/org-capture-entry-file ()
  "Prompt for a dir + file under org/; return its path (entry captures)."
  (my/org-pick-file-in (my/org-pick-dir my/org-dir)))

(defun my/org-capture-project-file ()
  "Prompt for dir + Projektname; return path. Name stashed for #+title."
  (setq my/org-capture-name (read-string "Projektname: "))
  (expand-file-name (concat (my/org-slug my/org-capture-name) ".org")
                    (my/org-pick-dir my/org-projects-dir)))

(defun my/org-capture-labor-file ()
  "Prompt for dir + Versuchsbezeichnung; return dated path. Name -> #+title."
  (setq my/org-capture-name (read-string "Versuchsbezeichnung: "))
  (expand-file-name
   (concat (format-time-string "%Y%m%d") "_"
           (my/org-slug my/org-capture-name) ".org")
   (my/org-pick-dir my/org-records-dir)))

(defun my/org-capture-meeting-file ()
  "Prompt for dir + file under org/; return path (meeting datetree target)."
  (my/org-pick-file-in (my/org-pick-dir my/org-records-dir)))

(defun my/org-project-id-link ()
  "Prompt for a project file anywhere under org/ (archive/ excluded) and
return an id link to it, or \"\" for none. Ensures the chosen file has a
file-level ID (creating one if needed), so org-roam backlinks list every
record taken for the project."
  (let* ((files (my/org-agenda-files))
         (rel   (mapcar (lambda (f) (file-relative-name f (expand-file-name org-directory))) files))
         (choice (completing-read "Projekt (leer = keins): " rel nil nil)))
    (if (or (null choice) (string-empty-p choice))
        ""
      (let ((abs (expand-file-name choice org-directory)))
        (with-current-buffer (find-file-noselect abs)
          (save-excursion
            (goto-char (point-min))
            (let ((id (org-id-get-create)))
              (save-buffer)
              (format "[[id:%s][%s]]" id (file-name-base abs)))))))))

(with-eval-after-load 'org
  (setq org-capture-templates
        '(("l" "Laborprotokoll" plain
           (file my/org-capture-labor-file)
           "#+title: %(my/org-capture-title)\n#+author: M. Winkler \n#+date: %<%Y-%m-%d>\n#+filetags: :labor:\n- Projekt :: %(my/org-project-id-link)\n\n* Aufbau und Messmittel\n%?\n\n* Verfahren\n# (optional – löschen falls nicht benötigt)\n\n* Versuch\n** Durchführung\n\n** Beobachtungen\n\n* Auswertung / Fazit\n"
           :unnarrowed t)
          ("p" "Projekt" plain
           (file my/org-capture-project-file)
           "#+title: %(my/org-capture-title)\n#+date: %<%Y-%m-%d>\n\n* Ziel\n%?\n\n* Aufgaben\n** TODO \n"
           :unnarrowed t)
          ("t" "Todo" entry
           (file my/org-capture-entry-file)
           "* TODO %?\n  %U\n")
          ("n" "Note" entry
           (file my/org-capture-entry-file)
           "* %?\n  %U\n")
          ;; Decisions are ENTITIES (ACTIVE). The project link is prompted
          ;; exactly like for Laborprotokoll/Meetings. Refile later to the
          ;; project's Decisions heading; overruled → M-m x s, never edit.
          ("d" "Decision" entry
           (file my/org-capture-entry-file)
           "* ACTIVE %^{Entscheidung}\n  %U\n  - Projekt :: %(my/org-project-id-link)\n  Kontext: %a\n  %?")
          ;; Meetings: a datetree of minutes in a file YOU pick under org/,
          ;; written once, never edited later. Decisions made in the meeting
          ;; get their own "d" capture and are linked here.
          ("m" "Meeting" entry
           (file+olp+datetree my/org-capture-meeting-file)
           "* %^{Thema}\n  - Teilnehmer :: %^{Teilnehmer}\n  - Projekt :: %(my/org-project-id-link)\n  %?"))))

;; Every capture becomes a node. EVERY captured file gets a file-level ID
;; (idempotent: returns the existing one if present) — the :PROPERTIES:
;; drawer at the top makes the file a linkable roam node and lets the
;; links it contains (e.g. the record's "Projekt ::" line) register as
;; backlinks on their targets. ENTRY captures (todo, decision, meeting)
;; additionally get ID + CREATED on the heading; PLAIN file captures
;; (Projekt, Laborprotokoll) also ID every TODO heading that came in via
;; the template. org-roam's own captures are skipped: roam manages those
;; IDs itself, and dailies would drown in property drawers.
(defun my/org-capture-stamp ()
  "Make the just-captured item a node (One Round System)."
  (unless (bound-and-true-p org-roam-capture--node)
    ;; Every file gets a file-level ID (the buffer is widened before this
    ;; hook runs, so point-min is the real file start):
    (save-excursion
      (goto-char (point-min))
      (org-id-get-create))
    (pcase (org-capture-get :type)
      ('entry
       (save-excursion
         (org-back-to-heading t)
         (org-id-get-create)
         (org-set-property "CREATED"
                           (format-time-string "[%Y-%m-%d %a %H:%M]"))))
      ('plain
       ;; TODO headings embedded in the template (e.g. a project's Aufgaben)
       ;; get IDs too, so every todo is linkable from birth:
       (org-map-entries
        (lambda ()
          (when (and (org-get-todo-state) (not (org-id-get)))
            (org-id-get-create)))
        nil 'file)))))
(add-hook 'org-capture-before-finalize-hook #'my/org-capture-stamp)

;; Manually typed TODO headings (added via M-RET / org-insert-todo-heading
;; / S-M-RET) get an ID automatically, so "every todo has an ID" holds
;; outside of capture too. Free-typed '* TODO foo' (plain text) is not
;; covered — use a heading command, or M-x org-id-get-create on it.
(defun my/org-id-new-todo-heading ()
  "Give a newly inserted TODO heading an ID if it lacks one."
  (ignore-errors
    (when (and (org-get-todo-state) (not (org-id-get)))
      (org-id-get-create))))
(add-hook 'org-insert-heading-hook #'my/org-id-new-todo-heading)

(defun my/org-supersede (&optional copy)
  "Supersede the entry at point with a successor sibling.
With prefix argument COPY (\\[universal-argument]), the successor starts
as a full copy of the old subtree — for reworking document-like entities.
Without it, the successor starts empty with the same title — for
decisions and approaches, where the new content is genuinely new.
Links predecessor and successor in both directions via ID, then marks
the old entry SUPERSEDED; org asks for the reason at the end (forced)."
  (interactive "P")
  (org-back-to-heading t)
  (let ((lvl    (org-outline-level))
        (old-id (org-id-get-create))
        (title  (org-get-heading t t t t))
        new-id)
    (if copy
        (progn
          (org-copy-subtree)
          (org-end-of-subtree t t)
          (let ((pos (point)))
            (org-paste-subtree lvl)
            (goto-char pos))
          (org-delete-property "ID"))
      (org-insert-heading-after-current)
      (insert title))
    (setq new-id (org-id-get-create))
    (org-set-property "SUPERSEDES" (format "[[id:%s]]" old-id))
    (org-entry-put nil "TODO" "ACTIVE")
    (save-excursion
      (org-id-goto old-id)
      (org-set-property "SUPERSEDED_BY" (format "[[id:%s]]" new-id))
      (org-todo "SUPERSEDED"))))

(defun my/org-delegate (person)
  "Hand the entry at point to PERSON: set OWNER, then enter DLGT.
The forced note is where the context goes that PERSON will need —
write it for them, not for yourself."
  (interactive "sDelegieren an: ")
  (org-set-property "OWNER" person)
  (org-todo "DLGT"))

(global-set-key (kbd "M-m x s") #'my/org-supersede)
(global-set-key (kbd "M-m x g") #'my/org-delegate)
(global-set-key (kbd "M-m x a") #'org-archive-subtree)

(defvar my/org-user user-login-name
  "Short name used in OWNER properties.
Keep it identical to your git user.name; teammates set their own
BEFORE this point (e.g. in a small site-local file) if needed.")

(setq org-agenda-custom-commands
      `(("m" "My work"
         ((todo "NEXT" ((org-agenda-overriding-header "Next")))
          (tags-todo ,(format "OWNER=\"%s\"" my/org-user)
                     ((org-agenda-overriding-header "Assigned to me")))
          (todo "WAIT|DLGT"
                ((org-agenda-overriding-header "Waiting on others")))))
        ("o" "Open decisions & paused things" todo "ACTIVE|ONHOLD")
        ("u" "Unowned actionables" tags-todo "TODO={TODO\\|NEXT}-OWNER={.}")
        ;; Today as a timeline of clocked intervals + clock report on
        ;; top: the automatically written diary of the day.
        ("d" "Today — timeline & clocked time" agenda ""
         ((org-agenda-span 'day)
          (org-agenda-start-with-log-mode '(clock))
          (org-agenda-clockreport-mode t)))))

(with-eval-after-load 'org
  (setq org-clock-persist 'history              ;; resume across restarts
        org-clock-in-resume t                   ;; continue an open clock
        org-clock-out-remove-zero-time-clocks t)
  (org-clock-persistence-insinuate))

(global-set-key (kbd "M-m i") #'org-clock-in)   ;; C-u M-m i: recent tasks
(global-set-key (kbd "M-m o") #'org-clock-out)
(global-set-key (kbd "M-m j") #'org-clock-goto) ;; jump to running clock

(use-package org-modern
  :hook ((org-mode . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))

(use-package org-download
  :after org
  :hook (dired-mode . org-download-enable)
  :bind (("M-m d s" . org-download-screenshot)
         ("M-m d y" . org-download-yank)
         ("M-m d d" . org-download-delete)
         :map org-mode-map
         ("C-S-v" . org-download-clipboard))
  :custom
  (org-download-method 'directory)
  (org-download-image-dir (expand-file-name "images" my/org-dir))
  (org-download-heading-lvl nil)
  ;; Eingefügte Bilder maximal 200 px breit:
  (org-download-image-org-width 200)
  ;; Keine "DOWNLOADED:"-Zeile unter den Links:
  (org-download-annotate-function (lambda (_link) ""))
  :config
  ;; org-download fügt normalerweise ein:
  ;;   :PROPERTIES:
  ;;   :DOWNLOADED: ...
  ;;   :END:
  ;;   #+DOWNLOADED: ...
  ;;   [[file:...]]
  ;; Wir wollen NUR den Link (mit optionalem ATTR_ORG für die Breite).
  ;; Dazu ersetzen wir `org-download-insert-link' komplett.
  (defun org-download-insert-link (_link filename)
    "Minimal replacement: insert ONLY the image link, no drawer, no DOWNLOADED."
    (let ((indent (current-indentation))
          (beg (point)))
      (insert (format "#+ATTR_ORG: :width %s\n[[file:%s]]\n"
                      (or org-download-image-org-width 200)
                      filename))
      ;; Einrückung von der aktuellen Zeile übernehmen:
      (indent-rigidly beg (point) indent)))

  ;; Per-OS screenshot/clipboard tool.
  (cond
   ((eq system-type 'windows-nt)
    (setq org-download-screenshot-method
          (concat
           "powershell.exe -NoProfile -Command "
           "\"Add-Type -AssemblyName System.Windows.Forms;"
           "$img=[Windows.Forms.Clipboard]::GetImage();"
           "if($img){$img.Save('%s',"
           "[System.Drawing.Imaging.ImageFormat]::Png)}\"")))
   ((eq system-type 'darwin)
    (setq org-download-screenshot-method "screencapture -i %s"))
   ((executable-find "maim")
    (setq org-download-screenshot-method "maim -s %s"))
   ((executable-find "scrot")
    (setq org-download-screenshot-method "scrot -s %s"))
   ((executable-find "import")
    (setq org-download-screenshot-method "import %s")))
  ;; Auto-refresh inline images after pasting.
  (advice-add 'org-download-clipboard  :after (lambda (&rest _) (org-redisplay-inline-images)))
  (advice-add 'org-download-screenshot :after (lambda (&rest _) (org-redisplay-inline-images))))

;; IMPORTANT: do NOT add image extensions here — openwith would intercept
;; org's own inline image rendering and shell them out to the OS viewer.
(use-package openwith
  :config
  (let ((opener (cond ((eq system-type 'windows-nt)
                       ;; rundll32 is the closest Windows equivalent of xdg-open
                       '("rundll32" ("url.dll,FileProtocolHandler" file)))
                      ((eq system-type 'darwin) '("open" (file)))
                      (t '("xdg-open" (file))))))
    (setq openwith-associations
          `(("\\.pdf\\'" ,(car opener) ,(cadr opener))
            ("\\.\\(?:mp4\\|mkv\\|webm\\|avi\\)\\'" ,(car opener) ,(cadr opener)))))
  (openwith-mode 1))

(use-package ob-mermaid
  :after org
  :custom
  ;; npm i -g @mermaid-js/mermaid-cli — then set the path:
  (ob-mermaid-cli-path (or (executable-find "mmdc") "mmdc"))
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((mermaid . t) (shell . t) (python . t) (emacs-lisp . t)))))

;; org-roam-directory is the WHOLE org tree: every heading with an ID is a
;; node, so backlinks span projects, areas, records, dailies AND the archive
;; folders. That is what keeps moment-records safely immutable — a daily
;; note's link to a task still resolves after the task was archived.
;; Atomic notes of EVERY type share notes/ — like records/, the type is a
;; filetag, never a folder:
;;   :concept:    timeless "what is X" Zettel (rewrite freely)
;;   :collection: items with lifecycles (movies, places, …)
(use-package org-roam
  :init (setq org-roam-v2-ack t)
  :custom
  (org-roam-directory my/org-dir)
  (org-roam-completion-everywhere t)
  (org-roam-dailies-directory "dailies/")
  (org-roam-capture-templates
   '(("c" "concept (Zettel)" plain "%?"
      :if-new (file+head "notes/%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+date: %U\n#+filetags: :concept:\n")
      :unnarrowed t)
     ("k" "collection item" plain "%?"
      :if-new (file+head "notes/%<%Y%m%d%H%M%S>-${slug}.org"
                         "#+title: ${title}\n#+date: %U\n#+filetags: :collection:\n* TODO ${title}\n")
      :unnarrowed t)))
  (org-roam-dailies-capture-templates
   '(("d" "default" entry "* %<%H:%M> %?"
      :if-new (file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d>\n"))))
  :bind (("M-m n l" . org-roam-buffer-toggle)
         ("M-m n f" . org-roam-node-find)
         ("M-m n i" . org-roam-node-insert)
         ("M-m n c" . org-roam-capture)
         ("M-m n t" . org-roam-tag-add)
         ("M-m n j" . org-roam-dailies-capture-today)
         ("M-m n d" . org-roam-dailies-goto-today)
         ("M-m n p" . org-roam-dailies-goto-previous-note)
         ("M-m n n" . org-roam-dailies-goto-next-note))
  :config
  (org-roam-db-autosync-mode))

(use-package websocket :after org-roam)
(use-package simple-httpd :after org-roam)
(use-package org-roam-ui
  :after org-roam
  :custom
  (org-roam-ui-sync-theme t)
  (org-roam-ui-follow t)
  (org-roam-ui-update-on-save t)
  (org-roam-ui-open-on-start t))

(use-package org-transclusion
  :after org
  :bind (("M-m t" . org-transclusion-mode)))

(use-package org-edna
  :after org
  :config (org-edna-mode 1))

(use-package org-super-agenda
  :after org
  :config
  (setq org-super-agenda-groups
        '((:name "Today"  :time-grid t :scheduled today)
          (:name "Next"   :todo "NEXT")
          (:name "Waiting / delegated" :todo ("WAIT" "DLGT"))
          (:name "Important" :priority "A")
          (:name "Overdue" :deadline past)
          (:name "Due soon" :deadline future)))
  (org-super-agenda-mode 1))

;; Marginalia (and org-timeblock) call `seconds-to-string' with 3 args,
;; but the built-in subr only accepts 1. Override early so it accepts extras.
;; Redefine only when the current definition accepts FEWER than the 3 args
;; marginalia passes (newer Emacs versions already accept them natively).
;; time-date must be loaded first — on an autoload stub, `func-arity' errors:
(require 'time-date)
(let ((max-arity (cdr (func-arity (symbol-function 'seconds-to-string)))))
  (when (and (numberp max-arity) (< max-arity 3))
    (defun seconds-to-string (delay &rest _ignored)
    "Convert the time DELAY, in seconds, to a string."
    (cond ((< delay 0) (format "-%s" (seconds-to-string (- delay))))
          ((>= delay (* 1 60 60 24 365.25))
           (format "%.1fy" (/ delay (* 1 60 60 24 365.25))))
          ((>= delay (* 1 60 60 24 30.4375))
           (format "%.1fmo" (/ delay (* 1 60 60 24 30.4375))))
          ((>= delay (* 1 60 60 24))
           (format "%.1fd" (/ delay (* 1 60 60 24))))
          ((>= delay (* 1 60 60))
           (format "%.1fh" (/ delay (* 1 60 60))))
          ((>= delay (* 1 60))
           (format "%.1fm" (/ delay (* 1 60))))
          (t (format "%.1fs" delay))))))

(use-package org-timeblock
  :defer t
  :commands (org-timeblock org-timeblock-list))

;; Org mode typst export
(use-package ox-typst
  :after org)

(defun my/org-gantt--date (ts)
  "Extract YYYY-MM-DD from an org timestamp string TS, or nil."
  (when (and ts (string-match "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" ts))
    (match-string 0 ts)))

(defun my/org-gantt--days (effort)
  "EFFORT string (\"3d\", \"2:00\") -> whole days, minimum 1."
  (or (when effort
        (ignore-errors
          (max 1 (round (/ (org-duration-to-minutes effort) 1440.0)))))
      1))

(defun my/org-gantt--blockers (blocker)
  "Extract the list of ids from an org-edna BLOCKER property string."
  (when (and blocker (string-match "ids(\\([^)]*\\))" blocker))
    (split-string (match-string 1 blocker) "[ \t,\"]+" t)))

(defun my/org-gantt--clean (name)
  "Strip characters mermaid chokes on in task NAMEs."
  (replace-regexp-in-string "[:,#]" "-" name))

(defun my/org-mermaid-gantt ()
  "Return Mermaid gantt source for all TODO headlines in the current buffer."
  (require 'org-duration)
  (let ((ids (make-hash-table :test #'equal)) ; org ID/CUSTOM_ID -> mermaid id
        (n 0) entries)
    ;; Pass 1: collect tasks, assign short mermaid ids.
    (org-map-entries
     (lambda ()
       ;; Tasks only: the artifact states (ACTIVE/ONHOLD/FINISHED/
       ;; SUPERSEDED/DROPPED — decisions, documents, processes) carry no
       ;; schedule semantics and stay out of the gantt.
       (when (member (org-get-todo-state)
                     '("TODO" "NEXT" "WAIT" "DLGT" "DONE" "CANCELLED"))
         (let* ((oid (or (org-entry-get nil "ID")
                         (org-entry-get nil "CUSTOM_ID")))
                (mid (format "t%d" (setq n (1+ n)))))
           (when oid (puthash oid mid ids))
           (push (list :mid mid
                       :name (my/org-gantt--clean (org-get-heading t t t t))
                       :todo (org-get-todo-state)
                       :prio (org-entry-get nil "PRIORITY")
                       :sched (my/org-gantt--date (org-entry-get nil "SCHEDULED"))
                       :dead  (my/org-gantt--date (org-entry-get nil "DEADLINE"))
                       :days  (my/org-gantt--days (org-entry-get nil "EFFORT"))
                       :deps  (my/org-gantt--blockers (org-entry-get nil "BLOCKER"))
                       :section (or (car (org-get-outline-path)) "Tasks"))
                 entries))))
     t nil)
    (setq entries (nreverse entries))
    ;; Pass 2: emit.
    (let ((title (my/org-gantt--clean
                  (or (cadr (assoc "TITLE" (org-collect-keywords '("TITLE"))))
                      (and buffer-file-name (file-name-base buffer-file-name))
                      "Project"))))
      (with-temp-buffer
        (insert "gantt\n"
                "  dateFormat YYYY-MM-DD\n"
                (format "  title %s\n" title))
        (let ((cur-section nil))
          (dolist (e entries)
            (unless (equal cur-section (plist-get e :section))
              (setq cur-section (plist-get e :section))
              (insert (format "  section %s\n" (my/org-gantt--clean cur-section))))
            (let* ((todo (plist-get e :todo))
                   (flags (concat
                           (cond ((member todo '("DONE" "CANCELLED")) "done, ")
                                 ((equal todo "NEXT") "active, ")
                                 (t ""))
                           (when (equal (plist-get e :prio) "A") "crit, ")))
                   (deps (delq nil (mapcar (lambda (d) (gethash d ids))
                                           (plist-get e :deps))))
                   (start (cond ((plist-get e :sched) (plist-get e :sched))
                                (deps (concat "after " (mapconcat #'identity deps " ")))
                                (t (format-time-string "%Y-%m-%d"))))
                   (end (or (plist-get e :dead)
                            (format "%dd" (plist-get e :days)))))
              (insert (format "  %s :%s%s, %s, %s\n"
                              (plist-get e :name) (or flags "")
                              (plist-get e :mid) start end)))))
        (buffer-string)))))

(defun my/org-gantt-export ()
  "Export the current org buffer as a Mermaid gantt chart.
Writes <file>.mmd next to the org file; if mmdc (mermaid-cli) is on PATH,
also renders <file>.svg and opens it."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not an org buffer"))
  (let* ((src (my/org-mermaid-gantt))
         (base (file-name-sans-extension
                (or buffer-file-name (expand-file-name "gantt" my/org-dir))))
         (mmd (concat base ".mmd"))
         (svg (concat base ".svg")))
    (with-temp-file mmd (insert src))
    (if (executable-find "mmdc")
        (progn
          (call-process "mmdc" nil nil nil "-i" mmd "-o" svg)
          (message "Gantt exported: %s" svg)
          (find-file-other-window svg))
      (message "Gantt source written to %s (npm i -g @mermaid-js/mermaid-cli to render)"
               mmd))))

(global-set-key (kbd "M-m p g") #'my/org-gantt-export)

;; (defun my/gptel-api-key ()
;;   "Read API key from opencode auth.json."
;;   (let ((auth-file (expand-file-name "~/.local/share/opencode/auth.json")))
;;     (when (file-exists-p auth-file)
;;       (with-temp-buffer
;;         (insert-file-contents auth-file)
;;         (goto-char (point-min))
;;         (when (re-search-forward "\"key\"\\s-*:\\s-*\"\\([^\"]+\\)\"" nil t)
;;           (match-string 1))))))

(use-package gptel
  ;; gptel-edit moved from M-m M-e to M-m M-g: in org buffers M-m M-e is
  ;; org-export-dispatch (mirrored C-c C-e) and would shadow it.
  :bind (("M-m g"   . gptel-menu)
         ("M-m G"   . gptel)
         ("M-m M-g" . gptel-edit)))
(gptel-make-anthropic "Claude-thinking" ;Any name you want
:key ""
:stream t
:models '(claude-sonnet-4-20250514 claude-3-7-sonnet-20250219)
:request-params '(:thinking (:type "enabled" :budget_tokens 2048)
                  :max_tokens 4096))

(defun my/copy-line-or-region (&optional arg)
  "Copy active region or current line to kill ring."
  (interactive "P")
  (if (use-region-p)
      (kill-ring-save (region-beginning) (region-end) arg)
    (kill-ring-save (line-beginning-position) (line-end-position) arg)))

(defun my/cut-line-or-region (&optional arg)
  "Cut active region or current line to kill ring."
  (interactive "P")
  (if (use-region-p)
      (kill-region (region-beginning) (region-end) arg)
    (kill-region (line-beginning-position) (line-end-position) arg)))

(global-set-key (kbd "C-c") #'my/copy-line-or-region)
(global-set-key (kbd "C-x") #'my/cut-line-or-region)
(global-set-key (kbd "C-v") #'yank)
(global-set-key (kbd "C-z") #'undo)
(global-set-key (kbd "C-S-z") #'undo-redo)   ;; VS Code: redo
(global-set-key (kbd "C-y") #'undo-redo)     ;; the other common redo key
(global-set-key (kbd "C-s") #'save-buffer)

;; Ctrl+Tab opens the same vertico buffer switcher as M-o b (consult-buffer).
;; Then Tab / C-Tab cycle the selection down and Shift-Tab / C-S-Tab cycle
;; it back — those bindings live in the vertico block further down, since
;; they only apply while the vertico list is open. consult previews the
;; buffer under the cursor live, so each tap shows that buffer; RET picks,
;; C-g aborts. Top of the list is the most-recent buffer (already previewed
;; when the list opens), so a single C-Tab + RET flips to the previous one.
(global-set-key (kbd "C-<tab>") #'consult-buffer)

;; Help lives on F1 (Emacs default); C-h becomes find & replace.
(global-set-key (kbd "C-S-p") #'execute-extended-command) ;; command palette
(global-set-key (kbd "C-p")   #'consult-buffer)  ;; quick open: buffers + recent files
(global-set-key (kbd "C-o")   #'find-file)       ;; open file
(global-set-key (kbd "C-h")   #'query-replace)   ;; find & replace (this buffer)

;; C-S-h: find & replace across the whole project (VS Code: Ctrl+Shift+H).
;; Inside a project (= git repo or project.el root) all project files are
;; used; otherwise you are asked for a directory (searched recursively).
;; In the query loop: y replace / n skip / ! rest of this file /
;; Y all remaining files / q stop.
(defun my/replace-in-files (from to)
  "Query-replace regexp FROM with TO across the current project.
Falls back to a prompted directory when not inside a project."
  (interactive
   (let ((common (query-replace-read-args "Replace in files (regexp)" t t)))
     (list (nth 0 common) (nth 1 common))))
  (require 'project)
  (require 'fileloop)
  (let* ((proj (project-current nil))
         (files (if proj
                    (project-files proj)
                  (directory-files-recursively
                   (read-directory-name "Replace in directory: ")
                   "." nil
                   (lambda (dir) (not (string-suffix-p "/.git" dir))))))
         ;; leave binary formats alone:
         (files (seq-remove
                 (lambda (f)
                   (string-match-p
                    "\.\(?:png\|jpe?g\|gif\|svg\|pdf\|zip\|7z\|exe\|docx?\|xlsx?\|pptx?\)\'"
                    f))
                 files)))
    (fileloop-initialize-replace from to files 'default)
    (fileloop-continue)))
(global-set-key (kbd "C-S-h") #'my/replace-in-files)
(global-set-key (kbd "C-a")   #'mark-whole-buffer) ;; select all (line start: Home)
(global-set-key (kbd "C-w")   #'kill-current-buffer) ;; close "tab"

(defun my/new-buffer ()
  "Create a fresh untitled buffer (VS Code: Ctrl+N)."
  (interactive)
  (switch-to-buffer (generate-new-buffer "untitled"))
  (text-mode))
(global-set-key (kbd "C-n") #'my/new-buffer)

;; C-g -> go to line (VS Code: Ctrl+G). C-g normally is Emacs' quit key, so:
;;  - while Emacs is BUSY, C-g still interrupts (handled below keymaps),
;;  - in the minibuffer it must still abort -> bound explicitly there,
;;  - for everything else, Esc is the cancel key (see below).
(global-set-key (kbd "C-g") #'consult-goto-line)
(define-key minibuffer-local-map (kbd "C-g") #'abort-minibuffers)
(with-eval-after-load 'vertico
  (define-key vertico-map (kbd "C-g") #'abort-minibuffers)
  ;; keep C-n/C-p moving the selection inside the completion UI:
  (define-key vertico-map (kbd "C-n") #'vertico-next)
  (define-key vertico-map (kbd "C-p") #'vertico-previous)
  ;; C-Tab opens the buffer list (global binding); then Tab / C-Tab cycle
  ;; the selection, Shift-Tab / C-S-Tab cycle back. consult previews each
  ;; buffer live; RET picks, C-g aborts.
  (define-key vertico-map (kbd "<tab>")             #'vertico-next)
  (define-key vertico-map (kbd "C-<tab>")           #'vertico-next)
  (define-key vertico-map (kbd "<backtab>")         #'vertico-previous)
  (define-key vertico-map (kbd "S-<iso-lefttab>")   #'vertico-previous)
  (define-key vertico-map (kbd "C-S-<iso-lefttab>") #'vertico-previous)
  (define-key vertico-map (kbd "C-S-<tab>")         #'vertico-previous))

(defun my/remap-leaders ()
  "Move mode-local C-c/C-x prefix bindings to M-m/M-o.
Mirrors C-<key> to M-<key> inside the local prefix maps, exposes them under
the leaders together with the global maps, then frees C-c/C-x so the global
copy/cut bindings shine through."
  (let ((cc (lookup-key (current-local-map) (kbd "C-c"))))
    (when (keymapp cc)
      (my/mirror-c-to-m cc)
      (local-set-key (kbd "M-m") (make-composed-keymap cc mode-specific-map))
      (local-set-key (kbd "C-c") nil)))
  (let ((cx (lookup-key (current-local-map) (kbd "C-x"))))
    (when (keymapp cx)
      (my/mirror-c-to-m cx)
      (local-set-key (kbd "M-o") (make-composed-keymap cx ctl-x-map))
      (local-set-key (kbd "C-x") nil))))
(add-hook 'after-change-major-mode-hook #'my/remap-leaders)

;; Consistent CUA-style session keys everywhere:
;;   C-s / C-RET  finish (file the capture / commit / apply edits)
;;   C-w          abort
;; These buffers use MINOR-mode maps that bind C-c C-c & co., which would
;; shadow C-c copy (minor maps outrank the global map and are not covered
;; by `my/remap-leaders'). `my/minor-cua-fix' moves each map's C-c prefix
;; under M-m (mirrored, so C-c C-k is also M-m M-k) and frees C-c for
;; copying. The "Finish with ..." hints in the header lines update
;; automatically, since they are generated from the actual bindings.

(with-eval-after-load 'org-capture        ;; also used by org-roam capture
  (my/minor-cua-fix org-capture-mode-map)
  (define-key org-capture-mode-map (kbd "C-s")        #'org-capture-finalize)
  (define-key org-capture-mode-map (kbd "C-<return>") #'org-capture-finalize)
  (define-key org-capture-mode-map (kbd "C-w")        #'org-capture-kill))

(with-eval-after-load 'org-src            ;; source-block editing (C-c ')
  (my/minor-cua-fix org-src-mode-map)
  (define-key org-src-mode-map (kbd "C-s")        #'org-edit-src-exit)
  (define-key org-src-mode-map (kbd "C-<return>") #'org-edit-src-exit)
  (define-key org-src-mode-map (kbd "C-w")        #'org-edit-src-abort))

(with-eval-after-load 'with-editor        ;; magit commit / rebase messages
  (my/minor-cua-fix with-editor-mode-map)
  (define-key with-editor-mode-map (kbd "C-s")        #'with-editor-finish)
  (define-key with-editor-mode-map (kbd "C-<return>") #'with-editor-finish)
  (define-key with-editor-mode-map (kbd "C-w")        #'with-editor-cancel))

(with-eval-after-load 'wgrep              ;; editable search results
  (my/minor-cua-fix wgrep-mode-map)
  (define-key wgrep-mode-map (kbd "C-s")        #'wgrep-finish-edit)
  (define-key wgrep-mode-map (kbd "C-<return>") #'wgrep-finish-edit)
  (define-key wgrep-mode-map (kbd "C-w")        #'wgrep-abort-changes))

;; Org note buffer (state-change reason, M-m M-z add-note, clock-out, …):
;; it's a plain org-mode buffer with `org-finish-function' set, so without
;; this the global CUA keys would mis-fire here (C-s -> save-buffer, C-w ->
;; kill-current-buffer). A buffer-local MINOR mode reroutes them to
;; finalize/abort, matching capture/src/commit/wgrep above. (A minor mode,
;; not `local-set-key', so we don't touch the shared `org-mode-map'.)
(defvar my/org-note-cua-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-s")        #'org-ctrl-c-ctrl-c) ; finalize note
    (define-key map (kbd "C-<return>") #'org-ctrl-c-ctrl-c)
    (define-key map (kbd "C-w")        #'org-kill-note-or-show-branches) ; abort
    map)
  "CUA finalize/abort keys for the transient *Org Note* buffer.")

(define-minor-mode my/org-note-cua-mode
  "CUA finalize/abort keys for the *Org Note* buffer."
  :keymap my/org-note-cua-map)

(defun my/org-note-cua-enable ()
  "Enable `my/org-note-cua-mode' and rewrite the hint line to match."
  (my/org-note-cua-mode 1)
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward
           "# Finish with C-c C-c, or cancel with C-c C-k\\." nil t)
      (replace-match
       "# Finish with C-s (or C-c C-c), or cancel with C-w."))))

(with-eval-after-load 'org
  (add-hook 'org-log-buffer-setup-hook #'my/org-note-cua-enable))

(add-hook 'emacs-startup-hook
          (lambda ()
            ;; Mirror the global prefix maps once everything is loaded:
            ;; C-x C-s -> M-o M-s (save), C-x C-f -> M-o M-f (find file),
            ;; C-x C-c -> M-o M-c (quit), ...
            (my/mirror-c-to-m mode-specific-map)
            (my/mirror-c-to-m ctl-x-map)
            ;; Buffers created before init finished (*scratch*, *Messages*)
            ;; never ran `after-change-major-mode-hook' — remap them too so
            ;; C-c/C-x copy/cut work there as well:
            (dolist (buf (buffer-list))
              (with-current-buffer buf
                (when (current-local-map) (my/remap-leaders))))))

;; Shift-selection everywhere, including org-mode. With the value t,
;; Shift-arrows select text normally, EXCEPT in org's special spots where
;; selecting makes no sense anyway: on a headline S-right/S-left cycles the
;; TODO state, on a timestamp S-up/S-down shifts the date. ('always would
;; disable those org behaviours completely — don't use it.)
(setq shift-select-mode t
      org-support-shift-select t)

(defun my/kill-whole-line ()
  "Delete the current line including its newline (no copy to clipboard)."
  (interactive)
  (delete-region (line-beginning-position)
                 (min (point-max) (1+ (line-end-position)))))
(global-set-key (kbd "C-S-k") #'my/kill-whole-line)

(defun my/comment-line-or-region ()
  "Comment/uncomment region if active, else current line."
  (interactive)
  (if (use-region-p)
      (comment-or-uncomment-region (region-beginning) (region-end))
    (comment-or-uncomment-region (line-beginning-position) (line-end-position))))
(global-set-key (kbd "C-/") #'my/comment-line-or-region)

;; Uses `move-text` for clean behaviour with active regions.
(use-package move-text
  :bind (("M-<up>"   . move-text-up)
         ("M-<down>" . move-text-down)))

(defun my/duplicate-line-or-region (&optional n)
  "Duplicate current line, or region if active. N=times."
  (interactive "p")
  (let ((n (or n 1)))
    (if (use-region-p)
        (let* ((beg (region-beginning))
               (end (region-end))
               (text (buffer-substring-no-properties beg end)))
          (goto-char end)
          (dotimes (_ n) (insert text)))
      (let ((line (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
        (end-of-line)
        (dotimes (_ n) (insert "\n" line))))))
(global-set-key (kbd "M-S-<down>") #'my/duplicate-line-or-region)
(global-set-key (kbd "M-S-<up>")   #'my/duplicate-line-or-region)

(use-package multiple-cursors
  :bind
  (("C-d"     . mc/mark-next-like-this-word)   ;; expand to next occurrence
   ("C-S-d"   . mc/mark-previous-like-this-word)
   ("C-S-l"   . mc/mark-all-like-this-dwim)    ;; select all occurrences
   ("C-M-d"   . mc/edit-lines)                 ;; one cursor per line in region
   ("C-M-<down>" . mc/mark-next-lines)         ;; VS Code's C-Alt-Down
   ("C-M-<up>"   . mc/mark-previous-lines)     ;; VS Code's C-Alt-Up
   ("M-<mouse-1>" . mc/add-cursor-on-click)))  ;; Alt-click adds a cursor

;; By default Esc in Emacs is a Meta prefix. Most people coming from VS Code
;; expect Esc to abort selections / multi-cursor / minibuffer.
(defun my/keyboard-escape-quit ()
  "Cancel current action: minibuffer, region, multiple cursors, etc."
  (interactive)
  (cond
   ;; In the minibuffer? Close it.
   ((active-minibuffer-window) (abort-recursive-edit))
   ;; Multi-cursor mode active? Leave it and clear all leftover regions.
   ((bound-and-true-p multiple-cursors-mode)
    (multiple-cursors-mode 0)
    (deactivate-mark)
    ;; mc/keyboard-quit also clears the fake-cursor overlays cleanly:
    (when (fboundp 'mc/keyboard-quit) (mc/keyboard-quit)))
   ;; Just a region? Deselect it.
   ((use-region-p) (deactivate-mark))
   ;; Fallback: standard abort.
   (t (keyboard-quit))))
(global-set-key (kbd "<escape>") #'my/keyboard-escape-quit)

(use-package eshell
  :ensure nil
  :custom
  (eshell-scroll-to-bottom-on-input t)
  (eshell-scroll-show-maximum-output t)
  (eshell-history-size 1000)
  (eshell-buffer-maximum-lines 10000)
  (eshell-hist-ignoredups t)
  (eshell-aliases-file (expand-file-name "eshell-aliases" user-emacs-directory))
  :config
  (require 'em-term)
  (add-to-list 'eshell-visual-commands '("htop" "top" "less" "more" "tail" "vim" "nano"))
  (add-to-list 'eshell-visual-subcommands '("git" "log" "diff" "show")))

(defun my/eshell-toggle ()
  "Toggle an eshell buffer in the current window or pop back."
  (interactive)
  (if (string= (buffer-name) "*eshell*")
      (bury-buffer)
    (eshell)))

(defun my/eshell-new ()
  "Open a fresh eshell instance."
  (interactive)
  (eshell 'N))

(global-set-key (kbd "C-`")   #'my/eshell-toggle)
(global-set-key (kbd "M-m e") #'my/eshell-new)

(use-package magit
  :bind (("M-o g" . magit-status))
  :custom
  (magit-display-buffer-function
   #'magit-display-buffer-same-window-except-diff-v1))

(defvar my/start-buffer-name "*Start*")

(define-derived-mode my/start-mode special-mode "Start"
  "Major mode for the startup screen."
  (setq-local display-line-numbers nil
              cursor-type nil
              truncate-lines t))

(defun my/start--heading (text)
  (insert (propertize text 'face '(:inherit font-lock-keyword-face :weight bold))
          "\n"))

(defun my/start--key (key desc)
  (insert "   "
          (propertize (format "%-14s" key) 'face 'font-lock-constant-face)
          (propertize desc 'face 'default)
          "\n"))

(defun my/start-screen ()
  "Build and return the startup screen buffer."
  (with-current-buffer (get-buffer-create my/start-buffer-name)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert "\n")
      (insert (propertize "   E M A C S\n" 'face
                          '(:inherit font-lock-keyword-face :weight bold :height 1.4)))
      (insert (propertize
               (let ((system-time-locale "C"))
                 (format "   %s\n\n" (format-time-string "%A, %d %B %Y")))
               'face 'font-lock-comment-face))

      (my/start--heading "  Files & buffers:")
      (my/start--key "C-p"     "Quick open (buffers + recent files)")
      (my/start--key "C-Tab" "Buffer switcher (Tab cycles, RET picks)")
      (my/start--key "C-o"     "Open file")
      (my/start--key "C-n"     "New untitled buffer")
      (my/start--key "C-w"     "Close buffer")
      (my/start--key "C-s"     "Save")
      (my/start--key "C-b"     "Toggle file tree (dirvish)")
      (my/start--key "M-m f r" "Recent files")
      (my/start--key "M-m f g" "Ripgrep across project")
      (my/start--key "M-o M-j" "Dired here")
      (insert "\n")

      (my/start--heading "  Dired (file manager):")
      (my/start--key "F2"      "Rename inline (C-s apply, C-w abort)")
      (my/start--key "C-S-n"   "New file (folder if name ends with /)")
      (my/start--key "C-c/C-x/C-v" "Copy / cut / paste files")
      (my/start--key "Del / S-Del" "Delete to trash / permanently")
      (my/start--key "Backspace" "Up one directory")
      (insert "\n")

      (my/start--heading "  Search & navigation:")
      (my/start--key "C-f"     "Find in buffer")
      (my/start--key "C-h"     "Find & replace")
      (my/start--key "C-g"     "Go to line")
      (my/start--key "M-g i"   "Outline (imenu)")
      (my/start--key "C-S-h"   "Replace in files (project-wide)")
      (my/start--key "C-S-p"   "Command palette (M-x)")
      (my/start--key "M-o 1/2/3/0" "Windows: only / below / right / close")
      (my/start--key "M-o o"   "Other window")
      (insert "\n")

      (my/start--heading "  Org & projects:")
      (my/start--key "M-m a"   "Agenda (a m = My work, a o = decisions)")
      (my/start--key "M-m c"   "Capture (t=Todo d=Decision m=Meeting l=Labor)")
      (my/start--key "M-m M-t" "Set state (reasons forced on @-states)")
      (my/start--key "M-m M-z" "Change note: log what/why on this entry")
      (my/start--key "M-m x s" "Supersede entry (C-u: successor = copy)")
      (my/start--key "M-m x g" "Delegate (OWNER + DLGT context note)")
      (my/start--key "M-m x a" "Archive subtree (-> archive/ next to file)")
      (my/start--key "M-m i/o" "Clock in (C-u: recent task) / clock out")
      (my/start--key "M-m j"   "Jump to running clock")
      (my/start--key "M-m a d" "Today: timeline of clocked time")
      (my/start--key "M-m p a" "Agenda for a subfolder")
      (my/start--key "M-m p f" "Agenda for this file only")
      (my/start--key "M-m p g" "Gantt export (Mermaid)")
      (my/start--key "M-m n f" "Roam: find note")
      (my/start--key "M-m n j" "Roam: today's daily")
      (my/start--key "S-→/←"   "Cycle TODO state (on a heading)")
      (my/start--key "M-o g"   "Magit (git) status")
      (insert "\n")

      (my/start--heading "  Editing:")
      (my/start--key "C-c / C-x / C-v" "Copy / cut / paste (whole line if no selection)")
      (my/start--key "C-z / C-y" "Undo / redo")
      (my/start--key "C-d"     "Multi-cursor: next occurrence")
      (my/start--key "C-S-l"   "Multi-cursor: all occurrences")
      (my/start--key "C-/"     "Toggle comment")
      (my/start--key "M-↑/↓"   "Move line(s)")
      (my/start--key "M-S-↑/↓" "Duplicate line(s)")
      (my/start--key "C-S-k"   "Delete line")
      (my/start--key "Esc"     "Cancel")
      (my/start--key "C-s / C-RET" "Finish capture / commit / src edit")
      (my/start--key "C-w"     "Abort capture / commit (elsewhere: close buffer)")
      (insert "\n")

      (my/start--heading "  Appearance:")
      (my/start--key "M-m T"   "Toggle theme (dark ⇄ light)")
      (insert "\n")

      (insert (propertize
               "   M-m ≙ C-c, M-o ≙ C-x — every mode binding: C-c C-x → M-m M-x\n"
               'face 'font-lock-comment-face))
      (insert (propertize
               "   Help is on F1 (F1 k = describe key, F1 f = function, …)\n"
               'face 'font-lock-comment-face))
      (goto-char (point-min)))
    (my/start-mode)
    (current-buffer)))

;; Show it at startup (only when Emacs was started without a file argument):
(setq initial-buffer-choice #'my/start-screen)

;; Reopen anytime:
(global-set-key (kbd "M-m h") (lambda () (interactive)
                                (switch-to-buffer (my/start-screen))))
