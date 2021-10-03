;;; boxy-headlines.el --- View org files in a boxy diagram -*- lexical-binding: t -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Tyler Grinn <tylergrinn@gmail.com>
;; Version: 1.0.0
;; File: boxy-headlines.el
;; Package-Requires: ((emacs "26.1") (boxy "1.0"))
;; Keywords: tools
;; URL: https://gitlab.com/tygrdev/boxy-headlines

;; This program is free software; you can redistribute it and/or modify
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

;; The command `boxy-headlines' will display all headlines in the
;; current org file as a boxy diagram.  The relationship between
;; a headline and its parent can be set by using a REL property on the
;; child headline.  Valid values for REL are:
;;
;;   - on top of
;;   - in front of
;;   - behind
;;   - above
;;   - below
;;   - to the right of
;;   - to the left of
;;
;;   The tooltip in `boxy-headlines' shows the values for each row
;;   in `org-columns' and can be customized the same way as org
;;   columns view.

;;; Code:

;;;; Requirements

(require 'boxy)
(require 'eieio)
(require 'org-element)
(require 'org-colview)
(require 'cl-lib)

;;;; Options

(defgroup boxy-headlines nil
  "Customization options for boxy-headlines"
  :group 'applications)

(defcustom boxy-headlines-margin-x 2
  "Horizontal margin to be used when displaying boxes."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-margin-y 1
  "Vertical margin to be used when displaying boxes."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-padding-x 2
  "Horizontal padding to be used when displaying boxes."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-padding-y 1
  "Vertical padding to be used when displaying boxes."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-include-context t
  "Whether to show context when opening a real link."
  :type 'boolean
  :group 'boxy-headlines)

(defcustom boxy-headlines-flex-width 80
  "When merging links, try to keep width below this."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-default-visibility 1
  "Default level to display boxes."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-tooltips t
  "Show tooltips in a boxy diagram."
  :type 'boolean
  :group 'boxy-headlines)

(defcustom boxy-headlines-tooltip-timeout 0.5
  "Idle time before showing tooltip in a boxy diagram."
  :type 'number
  :group 'boxy-headlines)

(defcustom boxy-headlines-tooltip-max-width 30
  "Maximum width of all tooltips."
  :type 'number
  :group 'boxy-headlines)

;;;; Faces

(defface boxy-headlines-default nil
  "Default face used in boxy mode."
  :group 'boxy-headlines)

(defface boxy-headlines-primary nil
  "Face for highlighting the name of a box."
  :group 'boxy-headlines)

(face-spec-set
 'boxy-headlines-primary
 '((((background dark)) (:foreground "turquoise"))
   (t (:foreground "dark cyan")))
 'face-defface-spec)

(defface boxy-headlines-selected nil
  "Face for the current box border under cursor."
  :group 'boxy-headlines)

(face-spec-set
 'boxy-headlines-selected
 '((t :foreground "light slate blue"))
 'face-defface-spec)

(defface boxy-headlines-rel nil
  "Face for the box which is related to the box under the cursor."
  :group 'boxy-headlines)

(face-spec-set
 'boxy-headlines-rel
 '((t :foreground "hot pink"))
 'face-defface-spec)

(defface boxy-headlines-tooltip nil
  "Face for tooltips in a boxy diagram."
  :group 'boxy-headlines)

(face-spec-set
 'boxy-headlines-tooltip
 '((((background dark)) (:background "gray30" :foreground "gray"))
   (t (:background "gainsboro" :foreground "dim gray")))
 'face-defface-spec)

;;;; Pretty printing

(cl-defun boxy-headlines-pp (box
                       &key
                       (display-buffer-fn 'display-buffer-pop-up-window)
                       (visibility boxy-headlines-default-visibility)
                       (max-visibility 2)
                       select
                       header
                       (default-margin-x boxy-headlines-margin-x)
                       (default-margin-y boxy-headlines-margin-y)
                       (default-padding-x boxy-headlines-padding-x)
                       (default-padding-y boxy-headlines-padding-y)
                       (flex-width boxy-headlines-flex-width)
                       (tooltips boxy-headlines-tooltips)
                       (tooltip-timeout boxy-headlines-tooltip-timeout)
                       (tooltip-max-width boxy-headlines-tooltip-max-width)
                       (default-face 'boxy-headlines-default)
                       (primary-face 'boxy-headlines-primary)
                       (tooltip-face 'boxy-headlines-tooltip)
                       (rel-face 'boxy-headlines-rel)
                       (selected-face 'boxy-headlines-selected))
  "Pretty print BOX in a popup buffer.

If HEADER is passed in, it will be printed above the diagram.

DISPLAY-BUFFER-FN is used to display the diagram, by
default `display-buffer-pop-up-window'.

If SELECT is non-nil, select the boxy window after displaying
it.

VISIBILITY is the initial visibility of children and
MAX-VISIBILITY is the maximum depth to display when cycling
visibility.

DEFAULT-MARGIN-X, DEFAULT-MARGIN-Y, DEFAULT-PADDING-X and
DEFAULT-PADDING-Y will be the fallback values to use if a box's
margin and padding slots are not set.

When adding boxes, boxy will try to keep the width below
FLEX-WIDTH.

If TOOLTIPS is nil, don't show any tooltips.

TOOLTIP-TIMEOUT is the idle time to wait before showing a
tooltip.

TOOLTIP-MAX-WIDTH is the maximum width of a tooltip.  Lines
longer than this will be truncated.

DEFAULT-FACE, PRIMARY-FACE, TOOLTIP-FACE, REL-FACE, and
SELECTED-FACE can be set to change the appearance of the boxy
diagram."
  (boxy-pp box
           :display-buffer-fn display-buffer-fn
           :visibility visibility
           :max-visibility max-visibility
           :select select
           :header header
           :default-margin-x default-margin-x
           :default-margin-y default-margin-y
           :default-padding-x default-padding-x
           :default-padding-y default-padding-y
           :flex-width flex-width
           :tooltips tooltips
           :tooltip-timeout tooltip-timeout
           :tooltip-max-width tooltip-max-width
           :default-face default-face
           :primary-face primary-face
           :tooltip-face tooltip-face
           :rel-face rel-face
           :selected-face selected-face))

;;;; Commands

(defun boxy-headlines ()
  "View all org headlines as a boxy diagram."
  (interactive)
  (let ((path (seq-filter
               'identity
               (append (list (org-entry-get nil "ITEM"))
                       (reverse (org-get-outline-path)))))
        (world (save-excursion (boxy-headlines--parse-headlines)))
        match)
    (boxy-headlines-pp world
             :display-buffer-fn 'display-buffer-same-window
             :select t)
    (while (and path (or (not match) (not (boxy-is-visible match t))))
      (setq match (boxy-find-matching (boxy-box :name (pop path)) world)))
    (when match
      (with-current-buffer (get-buffer "*Boxy*")
        (boxy-jump-to-box match)))))

;;;; Boxy implementation

(cl-defmethod boxy-headlines--add-headline (headline
                                            (parent boxy-box))
  "Add HEADLINE to world as a child of PARENT."
  (with-slots (markers (parent-level level)) parent
    (with-current-buffer (marker-buffer (car markers))
      (let* ((partitioned (seq-group-by
                           (lambda (h)
                             (let ((child-rel (or (org-entry-get
                                                   (org-element-property :begin h)
                                                   "REL")
                                                  "in")))
                               (if (member child-rel boxy-children-relationships)
                                   'children
                                 'siblings)))
                           (cddr headline)))
             (children (alist-get 'children partitioned))
             (siblings (alist-get 'siblings partitioned))
             (pos (org-element-property :begin headline))
             (columns (save-excursion (goto-char pos) (org-columns--collect-values)))
             (max-column-length (apply 'max 0
                                       (mapcar
                                        (lambda (column)
                                          (length (cadr (car column))))
                                        columns)))
             (rel (save-excursion (goto-char pos) (or (org-entry-get nil "REL") "in")))
             (level (if (member rel boxy-children-relationships)
                        (+ 1 parent-level)
                      parent-level))
             (name (org-element-property :title headline))
             (box (boxy-box :name (if (string-match org-link-bracket-re name)
                                      (match-string 2 name)
                                    name)
                            :rel rel
                            :level level
                            :rel-box parent
                            :parent parent
                            :tooltip (mapconcat
                                       (lambda (column)
                                         (format
                                          (concat "%" (number-to-string max-column-length) "s : %s")
                                          (cadr (car column))
                                          (cadr column)))
                                       columns
                                       "\n")
                            :markers (list (set-marker (point-marker) pos))
                            :in-front (string= rel "in front of")
                            :on-top (string= rel "on top of")
                            :y-order (cond
                                      ((string= rel "in front of") 1.0e+INF)
                                      ((string= rel "on top of") -1.0e+INF)
                                      (t 0))
                            :primary t)))
        (boxy-add-next box parent)
        (if children
            (object-add-to-list box :expand-children
                                `(lambda (box)
                                   (mapc
                                    (lambda (h) (org-real--add-headline h box))
                                    ',(alist-get 'children partitioned)))))
        (if siblings
            (object-add-to-list box :expand-siblings
                                `(lambda (box)
                                   (mapc
                                    (lambda (h) (org-real--add-headline h box))
                                    ',(alist-get 'siblings partitioned)))))))))

;;;; Utility expressions

(defun boxy-headlines--parse-headlines ()
  "Create a `boxy-box' from the current buffer's headlines."
  (org-columns-get-format)
  (let* ((headlines (cddr (org-element-parse-buffer 'headline)))
         (filename (buffer-name))
         (title (or (concat (file-name-base filename) "." (file-name-extension filename))
                    "Document"))
         (world (boxy-box))
         (document (boxy-box :name title
                             :tooltip ""
                             :markers (list (point-min-marker)))))
    (boxy-add-next document world)
    (mapc
     (lambda (headline)
        (boxy-headlines--add-headline headline document))
     headlines)
    world))

(provide 'boxy-headlines)

;;; boxy-headlines.el ends here
