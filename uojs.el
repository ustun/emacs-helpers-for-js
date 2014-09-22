(require 'dash)
(require 's)
(require 'projectile)

(defvar uojs--root-js-folder nil) ;; TODO: infer from .git folder like projectile

(defconst node-resolve-command-template "node -e 'try { console.log(require.resolve(\"%s\")) } catch (e) {}'")

(defvar ag-command "ag -i --nocolor --nogroup --ignore-dir=build --ignore-dir=south_migrations --ignore-dir=libs --ignore-dir=migrations --ignore=TAGS --ignore='*.min.css' --ignore='*.min.js'")


(defun uojs--get-current-line ()
  (thing-at-point 'line))

(defun uojs--ack-or-grep-mode ()
  (if (fboundp 'ack-mode)
      'ack-mode
    'grep-mode))

(defun uojs--file-path-from-require-line (whole-line)
  "Given whole line, recover the file-path inside the require call

Input: var MixpanelMixin = require('../mixins/mixpanel_mixin.react')
Output: ../mixins/mixpanel_mixin.react"

  (if (s-contains? "require(" whole-line)
      (let ((separator (if (s-contains? "'" whole-line) "'" "\"")))
        (cadr (s-split separator whole-line)))))


(defun uojs--resolve-node-module-path (file-path)
  "Given a required module (e.g. Backbone or '../../foo'),
resolve the absolute path using external node process"
  (s-chomp (shell-command-to-string (format node-resolve-command-template file-path))))


(defun uojs--get-require-file-path ()
  (-> (uojs--get-current-line)
    uojs--file-path-from-require-line
    uojs--resolve-node-module-path))


(defun uojs--get-require-line-for-module (module-reference)
  "Search the buffer for var module-reference line."
  (save-excursion
    (goto-char (point-min))
    (when (search-forward-regexp (format "^var %s" module-reference) nil t 1)
      (uojs--get-current-line))))


;; Interactive commands

(defun uojs-go-to-require-file-path ()
  (interactive)
  (let ((path (uojs--get-require-file-path)))
    (unless (string= "" path)
      (find-file path))))


(defun uojs-go-to-node-lib ()
  (interactive)
  (let ((lib-name  (read-string  "Node/JS lib name: ")))
    (unless (string= "" lib-name)
      (find-file (uojs--resolve-node-module-path lib-name)))))


(defun uojs-go-to-lib-for-current-module ()
  (interactive)
  (-> (uojs--get-require-line-for-module (thing-at-point 'word t))
    uojs--file-path-from-require-line
    uojs--resolve-node-module-path
    find-file))


(defun uojs-find-referencing ()
  (interactive)
  (let ((default-directory (or uojs--root-js-folder (projectile-project-root))))
    (compilation-start (concat ag-command  " -- " (file-name-base)) (uojs--ack-or-grep-mode))))


(defun uojs-find-referencing-files ()
  (interactive)
  (let ((default-directory (or uojs--root-js-folder (projectile-project-root))))
    (compilation-start (concat ag-command  " -l -- " (file-name-base)) (uojs--ack-or-grep-mode))))

(defun node-repl () (interactive)
       (pop-to-buffer (make-comint "node-repl" "node" nil "--interactive")))

(define-key js2-mode-map [M-return] 'uojs-go-to-require-file-path)

(provide 'uojs)

;;Bugs:
;; Does not properly handle the following
;;var EventEmitter = require('events').EventEmitter;
