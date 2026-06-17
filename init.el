;;; init.el --- Bootstrap for config.org -*- lexical-binding: t; -*-

;; Tangle and load the literate config (only re-tangles when .org is newer)
(org-babel-load-file
 (expand-file-name "config.org" user-emacs-directory))
