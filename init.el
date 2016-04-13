(require 'package)
(add-to-list 'package-archives
	     '("melpa" . "http://melpa.milkbox.net/packages/") t)
(package-initialize)

(setq inhibit-startup-message t)

(defalias 'yes-or-no-p 'y-or-n-p)

(defconst demo-packages
  '(company
    helm
    helm-gtags
    function-args
    clean-aindent-mode
    dtrt-indent
    ws-butler
    smartparens
    projectile))

(defun install-packages ()
  "Install all required packages."
  (interactive)
  (unless package-archive-contents
    (package-refresh-contents))
  (dolist (package demo-packages)
    (unless (package-installed-p package)
      (package-install package))))

(install-packages)

;; this variables must be set before load helm-gtags
;; you can change to any prefix key of your choice
(setq helm-gtags-prefix-key "\C-cg")

(add-to-list 'load-path "~/.emacs.d/custom")

(require 'setup-helm)
(require 'setup-helm-gtags)
(require 'setup-cedet)

;; function-args
(require 'function-args)
(fa-config-default)
(define-key c-mode-map  [(tab)] 'moo-complete)
(define-key c++-mode-map  [(tab)] 'moo-complete)

;; company
(require 'company)
(add-hook 'after-init-hook 'global-company-mode)
(delete 'company-semantic company-backends)
(define-key c-mode-map  [(control tab)] 'company-complete)
(define-key c++-mode-map  [(control tab)] 'company-complete)

;; company-c-headers
(add-to-list 'company-backends 'company-c-headers)

;; hs-minor-mode for folding source code
(add-hook 'c-mode-common-hook 'hs-minor-mode)

;; anaconda
(add-hook 'python-mode-hook 'anaconda-mode)

;; jedi
(add-hook 'python-mode-hook 'jedi:setup)
(setq jedi:complete-on-dot t)

;; Available C style:
;; “gnu”: The default style for GNU projects
;; “k&r”: What Kernighan and Ritchie, the authors of C used in their book
;; “bsd”: What BSD developers use, aka “Allman style” after Eric Allman.
;; “whitesmith”: Popularized by the examples that came with Whitesmiths C, an early commercial C compiler.
;; “stroustrup”: What Stroustrup, the author of C++ used in his book
;; “ellemtel”: Popular C++ coding standards as defined by “Programming in C++, Rules and Recommendations,” Erik Nyquist and Mats Henricson, Ellemtel
;; “linux”: What the Linux developers use for kernel development
;; “python”: What Python developers use for extension modules
;; “java”: The default style for java-mode (see below)
;; “user”: When you want to define your own style
(setq
 c-default-style "stroustrup"
 )
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))

;; indentation customize:
;; topmost-intro +
;; topmost-intro-cont 0

(global-set-key (kbd "RET") 'newline-and-indent)  ; automatically indent when press RET

;; activate whitespace-mode to view all whitespace characters
(global-set-key (kbd "C-c w") 'whitespace-mode)

;; show unncessary whitespace that can mess up your diff
(add-hook 'prog-mode-hook (lambda () (interactive) (setq show-trailing-whitespace 1)))

;; use space to indent by default
(setq-default indent-tabs-mode nil)

;; enable automatic saving of the desktop when I exit Emacs
(desktop-save-mode 1)

;; set appearance of a tab that is represented by 4 spaces
(setq-default tab-width 4)

;; Compilation
(global-set-key (kbd "<f5>") 'compile-dwim)
(defvar get-buffer-compile-command (lambda (file) (cons file 1)))
(make-variable-buffer-local 'get-buffer-compile-command)

(setq compilation-ask-about-save nil)
(setq-default compile-command "make -k -j ARCH=i386")

(defun compile-dwim (&optional arg)
  "Compile Do What I Mean.
    Compile using `compile-command'.
    When `compile-command' is empty prompt for its default value.
    With prefix C-u always prompt for the default value of
    `compile-command'.
    With prefix C-u C-u prompt for buffer local compile command with
    suggestion from `get-buffer-compile-command'.  An empty input removes
    the local compile command for the current buffer."
  (interactive "P")
  (cond
   ((and arg (> (car arg) 4))
    (let ((cmd (read-from-minibuffer
                "Buffer local compile command: "
                (funcall get-buffer-compile-command
                         (or (file-relative-name (buffer-file-name)) ""))
                nil nil 'compile-history)))
      (cond ((equal cmd "")
             (kill-local-variable 'compile-command)
             (kill-local-variable 'compilation-directory))
            (t
             (set (make-local-variable 'compile-command) cmd)
             (set (make-local-variable 'compilation-directory)
                  default-directory))))
    (when (not (equal compile-command ""))
      ;; `compile' changes the default value of
      ;; compilation-directory but this is a buffer local
      ;; compilation
      (let ((dirbak (default-value 'compilation-directory)))
        (compile compile-command)
        (setq-default compilation-directory dirbak))))
   ((or (and arg (<= (car arg) 4))
        (equal compile-command ""))
    (setq-default compile-command (read-from-minibuffer
                                   "Compile command: "
                                   (if (equal compile-command "")
                                       "make " compile-command)
                                   nil nil 'compile-history))
    (setq-default compilation-directory default-directory)
    (when (not (equal (default-value 'compile-command) ""))
      (compile (default-value 'compile-command))))
   (t
    (recompile))))

;; simple example:
(defun my-latex-mode ()
  (setq get-buffer-compile-command
        (lambda (file) (format "pdflatex %s" file))))
(add-hook 'latex-mode-hook 'my-latex-mode)

;; examples where `get-buffer-compile-command'
;; returns a cons cell (TEXT . CURSORPOS)

(defun my-c-mode ()
  (setq get-buffer-compile-command
        (lambda (file)
          (cons (format "gcc -Wall  -o %s %s && ./%s"
                        (file-name-sans-extension file)
                        file
                        (file-name-sans-extension file))
                11))))
(add-hook 'c-mode-hook 'my-c-mode)

(defun my-c++-mode ()
  (setq get-buffer-compile-command
        (lambda (file)
          (cons (format "g++ -Wall  -o %s %s && ./%s"
                        (file-name-sans-extension file)
                        file
                        (file-name-sans-extension file))
                11))))
(add-hook 'c++-mode-hook 'my-c++-mode)

(require 'ansi-color)
(defun colorize-compilation-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))
(add-hook 'compilation-filter-hook 'colorize-compilation-buffer)

;; setup GDB
(setq
 ;; use gdb-many-windows by default
 gdb-many-windows t

 ;; Non-nil means display source file containing the main routine at startup
 gdb-show-main t
 )

;; Package: clean-aindent-mode
(require 'clean-aindent-mode)
(add-hook 'prog-mode-hook 'clean-aindent-mode)

;; Package: dtrt-indent
(require 'dtrt-indent)
(dtrt-indent-mode 1)

;; Package: ws-butler
(require 'ws-butler)
(add-hook 'c-mode-common-hook 'ws-butler-mode)

;; Package: yasnippet
(require 'yasnippet)
(yas-global-mode 1)

;; Package: smartparens
(require 'smartparens-config)
(show-smartparens-global-mode +1)
(smartparens-global-mode 1)

;; Package: projejctile
(require 'projectile)
(projectile-global-mode)
(setq projectile-enable-caching t)
(setq projectile-completion-system 'helm)
(helm-projectile-on)

;; Package: p4
(require 'p4)

;; Environment variables
(setenv "JAVA_HOME"
   "/usr/lib/jvm/default-java"
)

(setq sonos-python-base-path
      (expand-file-name "~/daniel.casimiro_dcc_pts_team/depot/branches/pts_team/test/python")
)
(setenv "PYTHONPATH"
   (concat sonos-python-base-path "/core/src:"
           sonos-python-base-path "/tests/src:"
           sonos-python-base-path "/server/src:"
           sonos-python-base-path "/utilities/src")
)
(setenv "EXECUTION_ENVIRONMENT"
    (expand-file-name "~/emulator-settings/testbed.json")
)
(setenv "WORKSPACE"
        (expand-file-name "~/daniel.casimiro_dcc_pts_team/depot/branches/pts_team"))
(setenv "PATH"
        (concat (expand-file-name "~/.local/bin") (concat ":" (getenv "PATH"))))
(setenv "P4USER"
        "daniel.casimiro")
(setenv "P4CLIENT"
        "daniel.casimiro_dcc_pts_team")
(setenv "P4PORT"
        "ssl:p4p-camb.sonos.com:1666")
;(setq exec-path (append exec-path '(expand-file-name "~/.local/bin")))

;; iPython settings
(setq
 python-shell-interpreter "ipython"
 python-shell-interpreter-args ""
 python-shell-prompt-regexp "In \\[[0-9]+\\]: "
 python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: "
 python-shell-completion-setup-code
   "from IPython.core.completerlib import module_completion"
 python-shell-completion-module-string-code
   "';'.join(module_completion('''%s'''))\n"
 python-shell-completion-string-code
   "';'.join(get_ipython().Completer.all_completions('''%s'''))\n")

;; ess; julia
(setq inferior-julia-program-name "/Users/daniel.casimiro/src/julia/julia")

(message "Ready to play!")
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ede-project-directories (quote ("/home/dcc/src/daniel.casimiro_ubuntu1204_pts_team/depot/branches/pts_team/all")))
 '(p4-password-source "python -c \"import keyring, sys; print(keyring.get_password(*sys.argv[1:3]))\" \"$P4PORT\" \"$P4USER\""))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'upcase-region 'disabled nil)
