;;; early-init.el --- pre-init optimizations -*- lexical-binding: t; -*-

;; Reduce GC during startup, then restore a sane value afterwards.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 32 1024 1024)
                  gc-cons-percentage 0.1)))

;; Don't let package.el auto-init twice.
(setq package-enable-at-startup nil)

;; Disable chrome before it ever draws.
(push '(menu-bar-lines . 0)   default-frame-alist)
(push '(tool-bar-lines . 0)   default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq inhibit-startup-screen t
      frame-resize-pixelwise t)

;; Resizing the Emacs frame can be costly when changing the font.
(setq frame-inhibit-implied-resize t)

;;; early-init.el ends here
