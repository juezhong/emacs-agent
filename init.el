;;; init.el --- Generated Emacs configuration -*- lexical-binding: t; -*-
;; Generated from org_configs/Windows_config.org. Edit the Org source instead.

(defconst my/config-directory
  (file-name-directory (or load-file-name user-init-file))
  "Directory containing this configuration's generated init.el.")

(setq inhibit-startup-screen t
      initial-scratch-message ";; Org config loaded successfully.\n\n")

(require 'url-vars)

(defvar my/proxy-address "127.0.0.1:10808"
  "Local HTTP proxy address, or nil to omit explicit URL proxies.")

(setq url-proxy-services
      (when my/proxy-address
        `(("http" . ,my/proxy-address)
          ("https" . ,my/proxy-address)
          ("no_proxy" . "\\`\\(localhost\\|127\\.0\\.0\\.1\\|\\[::1\\]\\)\\'"))))

(require 'package)

(setq package-user-dir (expand-file-name "elpa/" my/config-directory)
      package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 30) ("nongnu" . 20) ("melpa" . 10)))

(require 'epg-config)

(when (eq system-type 'windows-nt)
  (let ((detected (executable-find epg-gpg-program))
        (affected "D:/Software/Msys2/usr/bin/gpg.exe")
        (replacement "D:/Software/Git/usr/bin/gpg.exe"))
    (when (and detected
               (string-equal (downcase detected) (downcase affected))
               (file-executable-p replacement))
      (customize-set-variable 'epg-gpg-program replacement)
      ;; Discard a cached configuration pointing to the affected executable.
      (setq epg--configurations nil))))

(setq package-gnupghome-dir (expand-file-name "gnupg/" package-user-dir))

(require 'epg)

(unless (epg-find-configuration 'OpenPGP)
  (error "GnuPG not found or unusable; install GnuPG and check Emacs exec-path"))

(let ((context (epg-make-context 'OpenPGP)))
  (setf (epg-context-home-directory context) package-gnupghome-dir)
  ;; A failed earlier attempt may have left an empty keybox behind.
  (unless (epg-list-keys context)
    (package-import-keyring (expand-file-name "package-keyring.gpg" data-directory))))

(package-initialize)

;; Fetch metadata if any configured archive is missing its cached index.
;; Refresh manually later with M-x package-refresh-contents.
(when (and (not noninteractive)
           (not (seq-every-p
                 (lambda (archive)
                   (file-exists-p
                    (expand-file-name
                     (concat "archives/" (car archive) "/archive-contents")
                     package-user-dir)))
                 package-archives)))
  (package-refresh-contents))

(unless (require 'use-package nil t)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package)
  (require 'use-package))

(setq use-package-always-ensure t)

(use-package org
  :ensure nil
  :defer t
  :custom
  (org-imenu-depth 4))

(use-package org-goto
  :ensure nil
  :defer t
  :custom
  (org-goto-interface 'outline-path-completion)
  (org-goto-max-level 4))

(use-package toc-org
  :hook (org-mode . toc-org-mode))

;;; init.el ends here
