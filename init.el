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
    helm-projectile
    fold-dwim
    clean-aindent-mode
    dtrt-indent
    org
    org-bullets
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

;; company
(require 'company)
(add-hook 'after-init-hook 'global-company-mode)
(delete 'company-semantic company-backends)
(define-key c-mode-map  [(control tab)] 'company-complete)
(define-key c++-mode-map  [(control tab)] 'company-complete)

;; ox-jira (export org mode to jira)
(require 'ox-jira)

;; ob-plantuml (render plantuml in org mode)
(require 'ob-plantuml)
(setq plantuml-jar-path "/home/dan/plantuml.jar")

;; company-c-headers
(add-to-list 'company-backends 'company-c-headers)

;; anaconda
(add-hook 'python-mode-hook 'anaconda-mode)

;; eshell
(add-hook 'eshell-preoutput-filter-functions
          'ansi-color-filter-apply)

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
(setq-default compile-command "make -r -k -j ARCH=amd64 BUILD_GUNIT_TESTS=1")

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

(defun org-repair-export-blocks ()
  "Repair export blocks and INCLUDE keywords in current buffer."
  (interactive)
  (when (eq major-mode 'org-mode)
    (let ((case-fold-search t)
          (back-end-re (regexp-opt
                        '("HTML" "ASCII" "LATEX" "ODT" "MARKDOWN" "MD" "ORG"
                          "MAN" "BEAMER" "TEXINFO" "GROFF" "KOMA-LETTER")
                        t)))
      (org-with-wide-buffer
       (goto-char (point-min))
       (let ((block-re (concat "^[ \t]*#\\+BEGIN_" back-end-re)))
         (save-excursion
           (while (re-search-forward block-re nil t)
             (let ((element (save-match-data (org-element-at-point))))
               (when (eq (org-element-type element) 'special-block)
                 (save-excursion
                   (goto-char (org-element-property :end element))
                   (save-match-data (search-backward "_"))
                   (forward-char)
                   (insert "EXPORT")
                   (delete-region (point) (line-end-position)))
                 (replace-match "EXPORT \\1" nil nil nil 1))))))
       (let ((include-re
              (format "^[ \t]*#\\+INCLUDE: .*?%s[ \t]*$" back-end-re)))
         (while (re-search-forward include-re nil t)
           (let ((element (save-match-data (org-element-at-point))))
             (when (and (eq (org-element-type element) 'keyword)
                        (string= (org-element-property :key element) "INCLUDE"))
               (replace-match "EXPORT \\1" nil nil nil 1)))))))))

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
(add-hook 'c++-mode-hook #'modern-c++-font-lock-mode)

;; hs-minor-mode for folding source code
(require 'hideshow)
(add-hook 'c-mode-common-hook 'hs-minor-mode)

;; customize fold-dwim
(require 'fold-dwim)
(global-set-key (kbd "<f7>")      'fold-dwim-toggle)
(global-set-key (kbd "<M-f7>")    'fold-dwim-hide-all)
(global-set-key (kbd "<S-M-f7>")  'fold-dwim-show-all)

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

;; Package: smartparens
(require 'smartparens-config)
(show-smartparens-global-mode +1)
(smartparens-global-mode 1)

;; Package: projejctile
;(require 'projectile)
;(setq projectile-enable-caching t)
;(setq projectile-completion-system 'helm)
;(helm-projectile-on)

;; kill unused buffers every night
(require 'midnight)
(midnight-delay-set 'midnight-delay "3:00am")

;; org-bullets
(require 'org-bullets)
(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))

;; Package: p4
(require 'p4)

;; Start an emacs daemon. This allows other programs (or me, manually)
;; to open a file with an already running instantiation of
;; Emacs.app. Note that this is typically accomplished by running the
;; command "emacs --daemon" to start the emacs server, followed by
;; subsequent "emacsclient <file>" commands to pass files to a running
;; emacs process. For Emacs.app, the commands are
;; "/Applications/Emacs.app/Contents/MacOS/Emacs --daemon" and
;; "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient <file>"
;; respectively. Rather than start the server from the terminal, you
;; can also do so with a running emacs process with the command "M-x
;; server-start". Alternatively, you can run that command at startup,
;; which is what I've chosen to do below. Note that another option is
;; to have this happen at boot time on OS X. See this link for
;; details:
;; http://superuser.com/questions/50095/how-can-i-run-mac-osx-graphical-emacs-in-daemon-mode
(require 'server)
(unless (server-running-p)
    (server-start))

;; Environment variables
(setenv "PATH"
        (concat (expand-file-name "~/.local/bin")
                (concat ":" (concat (expand-file-name "~/.cask/bin"))
                        (concat ":" (concat (expand-file-name "/usr/local/bin"))
                                (concat ":" (getenv "PATH"))))))
(setenv "P4USER"
        "daniel.casimiro")
(setenv "P4CLIENT"
        "daniel.casimiro_dcc_pts_team")
(setenv "P4PORT"
        "ssl:p4p-bos.sonos.com:1666")
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
(setq inferior-julia-program-name "/usr/local/bin/julia")

(require 'julia-shell)
(defun my-julia-mode-hooks ()
  (require 'julia-shell-mode))
(add-hook 'julia-mode-hook 'my-julia-mode-hooks)
(define-key julia-mode-map (kbd "C-c C-c") 'julia-shell-run-region-or-line)
(define-key julia-mode-map (kbd "C-c C-s") 'julia-shell-save-and-go)

(message "Ready to play!")
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-plantuml-jar-path "/home/dan/plantuml.jar")
 '(p4-password-source
   "python -c \"import keyring, sys; print(keyring.get_password(*sys.argv[1:3]))\" \"$P4PORT\" \"$P4USER\"")
 '(package-selected-packages
   (quote
    (yasnippet xcscope x509-mode ws-butler websocket w3m w3 tidy swiper strace-mode sphinx-frontend sphinx-doc soap-client smartparens smart-mode-line-powerline-theme sage-shell-mode rust-playground restclient replace-symbol redis rbt racer python-mode python-info pytest pylint pyenv-mode pydoc-info pydoc pycoverage py-test py-import-check py-gnitset py-autopep8 pug-mode project-persist playerctl plantuml-mode persistent-scratch pcache page-break-lines pacmacs ox-rst ox-jira ox-gfm overseer org-password-manager org-notebook org-jira org-bullets org-babel-eval-in-repl ob-rust nv-delete-back npm-mode mustache-mode mustache multi modern-cpp-font-lock markdown-mode makefile-executor magit-p4 magit-lfs magit-filenotify logito llvm-mode libmpdee julia-shell json-reformat jira-markup-mode jedi jade-mode inflections highlight-indentation hideshowvis helm-projectile helm-gtags gradle-mode gitignore-mode gh-md ggtags fold-dwim-org flymake-rust flycheck-rust filesets+ eww-lnum eshell-git-prompt esh-autosuggest elnode dtrt-indent dotenv-mode coverage confluence company-jedi company-c-headers company-anaconda cmake-project clean-aindent-mode cl-generic cargo bts auth-password-store anything alert))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
