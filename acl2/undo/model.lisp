; A readable model of emil's text, edits and undo/redo history.
;
; Follows undo.c and mutate.c at emil ac98ba0b.  Definitions only: nothing here is
; a claim.  Each function names the C it models.
;
; Not modelled: the dirty flag, the mark, other windows' points, registers, the
; INT_MAX size guards, memory, and buffers with no rows (numrows == 0).
(in-package "ACL2")

(include-book "../claims/spec")

;; ---- Text data ----
;
; The text itself is spec.lisp's non-empty list of lines.  The data in a record
; is flat: a list of bytes with :nl for each newline, as (flat tx) produces.

;; "a\nb" as lines.  The inverse of FLAT.
(defun split-lines (data)
  (if (endp data)
      (list nil)
    (let ((rest (split-lines (cdr data))))
      (if (equal (car data) :nl)
          (cons nil rest)
        (cons (cons (car data) (car rest)) (cdr rest))))))

;; collectRegionText: the flat text between two positions.
(defun region-text (tx sx sy ex ey)
  (let ((s (offset sx sy tx))
        (e (offset ex ey tx)))
    (take (- e s) (nthcdr s (flat tx)))))

;; bulkInsert's text change, from flat data.
(defun insert-data (tx sx sy data)
  (insert-text tx sx sy (split-lines data)))

;; computeInsertEnd
(defun data-end-x (sx data) (insert-end-x sx (split-lines data)))
(defun data-end-y (sy data) (insert-end-y sy (split-lines data)))

;; ---- History records ----

;; struct undo, less prev (a record's place in the list) and datasize (memory).
;; (px, py) is the cursor before the change; py = -1 means not recorded.
(defrec undo-rec
  (sx sy ex ey del data app paired nmerges uncapped px py)
  t)

(defun make-undo-rec (sx sy ex ey del data app paired uncapped px py)
  (make undo-rec :sx sx :sy sy :ex ex :ey ey :del del :data data :app app
        :paired paired :nmerges 0 :uncapped uncapped :px px :py py))

;; undoCloseRun: the next edit starts a fresh record.
(defun close-run (undo)
  (if (consp undo)
      (cons (change undo-rec (car undo) :app nil) (cdr undo))
    undo))

;; ---- Coalescing ----

(defconst *undo-merge-limit* 20) ; UNDO_MERGE_LIMIT

;; undoMerge's decision.  :append, :prepend, or :none.
;; The C's INT_MAX / 2 guard isn't modelled.
(defun merge-shape (prev new)
  (let ((p-sx (access undo-rec prev :sx)) (p-sy (access undo-rec prev :sy))
        (p-ex (access undo-rec prev :ex)) (p-ey (access undo-rec prev :ey))
        (n-sx (access undo-rec new :sx)) (n-sy (access undo-rec new :sy))
        (n-ex (access undo-rec new :ex)) (n-ey (access undo-rec new :ey)))
    (cond ((not (access undo-rec prev :app)) :none)
          ((not (equal (access undo-rec prev :del) (access undo-rec new :del))) :none)
          ((or (access undo-rec prev :paired) (access undo-rec new :paired)) :none)
          ((and (not (access undo-rec prev :uncapped))
                (not (access undo-rec new :uncapped))
                (>= (access undo-rec prev :nmerges) *undo-merge-limit*))
           :none)
          ((endp (access undo-rec new :data)) :none)
          ;; typing: the new text starts where the run ends
          ((not (access undo-rec new :del))
           (if (and (equal p-ex n-sx) (equal p-ey n-sy)) :append :none))
          ;; C-d: the new text starts where the run starts
          ((and (equal p-sx n-sx) (equal p-sy n-sy)) :append)
          ;; backspace: the new text ends where the run starts
          ((and (equal p-sx n-ex) (equal p-sy n-ey)) :prepend)
          (t :none))))

;; undoMerge's update.  The end is recomputed from the merged data.
(defun merge-recs (prev new shape)
  (let* ((prepend (equal shape :prepend))
         (sx (if prepend (access undo-rec new :sx) (access undo-rec prev :sx)))
         (sy (if prepend (access undo-rec new :sy) (access undo-rec prev :sy)))
         (data (if prepend
                   (append (access undo-rec new :data) (access undo-rec prev :data))
                 (append (access undo-rec prev :data) (access undo-rec new :data)))))
    (change undo-rec prev
            :sx sx :sy sy
            :ex (data-end-x sx data) :ey (data-end-y sy data)
            :data data
            :nmerges (+ 1 (access undo-rec prev :nmerges))
            :uncapped (or (access undo-rec prev :uncapped)
                          (access undo-rec new :uncapped)))))

;; pushUndo
(defun push-rec (new undo)
  (let ((shape (if (and (access undo-rec new :app) (consp undo))
                   (merge-shape (car undo) new)
                 :none)))
    (if (equal shape :none)
        (cons new (close-run undo))
      (cons (merge-recs (car undo) new shape) (cdr undo)))))

;; ---- Editor state ----

;; The part of struct buffer the model covers.
;; WANTS-NL is wantsFinalNewline: false only for the minibuffer.
(defrec edst
  (text undo redo cx cy wants-nl read-only)
  t)

;; ---- Edits ----

;; deletesOnlyFinalNewline
(defun deletes-only-final-nl-p (tx sx sy ex ey old repl)
  (let ((n (len tx)))
    (and (consp old)
         (endp repl)
         (>= n 2)
         (endp (nth (- n 1) tx))
         (consp (nth (- n 2) tx))
         (equal sy (- n 2))
         (equal sx (len (nth (- n 2) tx)))
         (equal ey (- n 1))
         (equal ex 0))))

;; Why an edit won't happen, or nil.  :invalid is the model's specification of
;; a bad range: C at ac98ba0b has no such outcome.
(defun edit-refusal (st sx sy ex ey repl)
  (let ((tx (access edst st :text)))
    (cond ((access edst st :read-only) :read-only)
          ((not (valid-delete-p tx sx sy ex ey)) :invalid)
          ((and (access edst st :wants-nl)
                (deletes-only-final-nl-p tx sx sy ex ey
                                         (region-text tx sx sy ex ey) repl))
           :final-newline)
          (t nil))))

;; restoreFinalNewline.  (bufferIsEmpty is covered: its last row is empty.)
(defun repair-final-nl (st)
  (let* ((tx (access edst st :text))
         (lastrow (car (last tx))))
    (if (and (access edst st :wants-nl) (consp lastrow))
        (let* ((y (- (len tx) 1))
               (x (len lastrow))
               (data (list :nl))
               (fix (make-undo-rec x y 0 (+ y 1) nil data nil t nil 0 -1)))
          (change edst st
                  :text (insert-data tx x y data)
                  :undo (push-rec fix (access edst st :undo))))
      st)))

;; mutateReplaceEx.  The deleted text comes from the buffer, not from the caller.
;; COALESCE is nil for mutateReplace and its wrappers, t for mutateInsertChar and
;; mutateDeleteChar.  BURST is E.input_burst.
(defun edit (st sx sy ex ey repl chain coalesce burst)
  (if (edit-refusal st sx sy ex ey repl)
      st
    (let* ((tx (access edst st :text))
           (old (region-text tx sx sy ex ey))
           (px (access edst st :cx))
           (py (access edst st :cy))
           (is-replace (and (consp old) (consp repl)))
           (co (and coalesce (not is-replace) (not chain)))
           (uncapped (and co burst))
           (undo (access edst st :undo))
           ;; the delete record and the deletion
           (undo (if (consp old)
                     (push-rec (make-undo-rec sx sy ex ey t old co (and chain t)
                                              uncapped px py)
                               undo)
                   undo))
           (tx (if (consp old) (delete-text tx sx sy ex ey) tx))
           ;; the insert record and the insertion
           (undo (if (consp repl)
                     (push-rec (make-undo-rec sx sy
                                              (data-end-x sx repl) (data-end-y sy repl)
                                              nil repl co (or is-replace (and chain t))
                                              uncapped px py)
                               undo)
                   undo))
           (tx (if (consp repl) (insert-data tx sx sy repl) tx)))
      (repair-final-nl (change edst st :text tx :undo undo :redo nil)))))

(defun nl-list (n)
  (if (zp n) nil (cons :nl (nl-list (- n 1)))))

(defun empty-rows (n)
  (if (zp n) nil (cons nil (empty-rows (- n 1)))))

;; mutateExtendRows: append N empty rows, recorded as one insert.
;; FROM must be the row count: :invalid otherwise, again the model's specification.
(defun extend-refusal (st from n)
  (cond ((access edst st :read-only) :read-only)
        ((zp n) :nothing)
        ((not (equal from (len (access edst st :text)))) :invalid)
        (t nil)))

(defun extend-rows (st from n)
  (if (extend-refusal st from n)
      st
    (let* ((tx (access edst st :text))
           (y (- from 1))
           (x (len (nth y tx)))
           (rec (make-undo-rec x y 0 (+ y n) nil (nl-list n) nil nil nil 0 -1)))
      (change edst st
              :text (append tx (empty-rows n))
              :undo (push-rec rec (access edst st :undo))
              :redo nil))))

;; ---- Undo and redo ----

;; undoStep with redo = 0: reverse the newest record and move it to the redo list.
(defun undo-step (st)
  (let* ((undo (access edst st :undo))
         (node (car undo))
         (tx (access edst st :text))
         (sx (access undo-rec node :sx)) (sy (access undo-rec node :sy))
         (ex (access undo-rec node :ex)) (ey (access undo-rec node :ey))
         (del (access undo-rec node :del))
         (px (access undo-rec node :px)) (py (access undo-rec node :py))
         (recorded (and (integerp py) (<= 0 py))))
    (change edst st
            :text (if del
                      (insert-data tx sx sy (access undo-rec node :data))
                    (delete-text tx sx sy ex ey))
            :cx (cond (recorded px) (del ex) (t sx))
            :cy (cond (recorded py) (del ey) (t sy))
            :undo (close-run (cdr undo))
            :redo (cons node (access edst st :redo)))))

;; undoStep with redo = 1: reapply the record and move it back to the undo list.
(defun redo-step (st)
  (let* ((redo (access edst st :redo))
         (node (car redo))
         (tx (access edst st :text))
         (sx (access undo-rec node :sx)) (sy (access undo-rec node :sy))
         (ex (access undo-rec node :ex)) (ey (access undo-rec node :ey))
         (del (access undo-rec node :del)))
    (change edst st
            :text (if del
                      (delete-text tx sx sy ex ey)
                    (insert-data tx sx sy (access undo-rec node :data)))
            :cx (if del sx ex)
            :cy (if del sy ey)
            :undo (close-run (cons node (access edst st :undo)))
            :redo (cdr redo))))

;; One group of doUndo: a paired record pulls the next one with it.
;; Returns (mv exhausted st): exhausted if a paired record had nothing before it.
(defun undo-group (st)
  (declare (xargs :measure (len (access edst st :undo))))
  (let ((undo (access edst st :undo)))
    (if (endp undo)
        (mv t st)
      (let ((paired (access undo-rec (car undo) :paired))
            (st1 (undo-step st)))
        (if paired
            (undo-group st1)
          (mv nil st1))))))

(defun undo-times (st n)
  (declare (xargs :measure (nfix n)))
  (cond ((zp n) (mv :done st))
        ((endp (access edst st :undo)) (mv :exhausted st))
        (t (mv-let (exhausted st1)
             (undo-group st)
             (if exhausted
                 (mv :exhausted st1)
               (undo-times st1 (- n 1)))))))

;; doUndo.  COUNT 0 means once, as UARG_COUNT does.
(defun do-undo (st count)
  (if (access edst st :read-only)
      (mv :refused st)
    (undo-times (change edst st :undo (close-run (access edst st :undo)))
                (if (zp count) 1 count))))

;; The paired records after the first of a redo group.  (PX, PY) is the point
;; carried through them.
(defun redo-rest (st px py)
  (declare (xargs :measure (len (access edst st :redo))))
  (let ((redo (access edst st :redo)))
    (if (and (consp redo) (access undo-rec (car redo) :paired))
        (let* ((n (car redo))
               (a (adjust-spec px py
                               (access undo-rec n :sx) (access undo-rec n :sy)
                               (access undo-rec n :ex) (access undo-rec n :ey)
                               (access undo-rec n :del))))
          (redo-rest (redo-step st) (adj-x a) (adj-y a)))
      (change edst st :cx px :cy py))))

(defun redo-group (st)
  (let ((node (car (access edst st :redo))))
    (redo-rest (redo-step st)
               (access undo-rec node :sx)
               (access undo-rec node :sy))))

(defun redo-times (st n)
  (declare (xargs :measure (nfix n)))
  (cond ((zp n) (mv :done st))
        ((endp (access edst st :redo)) (mv :exhausted st))
        (t (redo-times (redo-group st) (- n 1)))))

;; doRedo
(defun do-redo (st count)
  (if (access edst st :read-only)
      (mv :refused st)
    (redo-times (change edst st :undo (close-run (access edst st :undo)))
                (if (zp count) 1 count))))

;; ---- History matches text ----
;
; Undo replay checks neither order nor range: it relies on the history matching
; the text.  This is that assumption written down: each undo record, newest first,
; describes the text as it stands, and so on down the list once it is undone.
; Each redo record likewise, oldest-undone first.

(defun rec-range-ok-p (r)
  (and (natp (access undo-rec r :sx)) (natp (access undo-rec r :sy))
       (true-listp (access undo-rec r :data))
       (consp (access undo-rec r :data))
       (equal (access undo-rec r :ex)
              (data-end-x (access undo-rec r :sx) (access undo-rec r :data)))
       (equal (access undo-rec r :ey)
              (data-end-y (access undo-rec r :sy) (access undo-rec r :data)))))

;; The record's range exists in TX and holds the record's data.
(defun applied-p (r tx)
  (let ((sx (access undo-rec r :sx)) (sy (access undo-rec r :sy))
        (ex (access undo-rec r :ex)) (ey (access undo-rec r :ey)))
    (and (valid-delete-p tx sx sy ex ey)
         (equal (region-text tx sx sy ex ey) (access undo-rec r :data)))))

;; TX is the text just after every record in UNDO was applied.
(defun undo-matches-p (undo tx)
  (if (endp undo)
      t
    (let* ((r (car undo))
           (sx (access undo-rec r :sx)) (sy (access undo-rec r :sy))
           (ex (access undo-rec r :ex)) (ey (access undo-rec r :ey)))
      (and (rec-range-ok-p r)
           (if (access undo-rec r :del)
               ;; undoing it inserts at a position that exists
               (and (valid-insert-p tx sx sy (split-lines (access undo-rec r :data)))
                    (undo-matches-p (cdr undo)
                                    (insert-data tx sx sy (access undo-rec r :data))))
             (and (applied-p r tx)
                  (undo-matches-p (cdr undo) (delete-text tx sx sy ex ey))))))))

;; TX is the text just before every record in REDO is reapplied.
(defun redo-matches-p (redo tx)
  (if (endp redo)
      t
    (let* ((r (car redo))
           (sx (access undo-rec r :sx)) (sy (access undo-rec r :sy))
           (ex (access undo-rec r :ex)) (ey (access undo-rec r :ey)))
      (and (rec-range-ok-p r)
           (if (access undo-rec r :del)
               (and (applied-p r tx)
                    (redo-matches-p (cdr redo) (delete-text tx sx sy ex ey)))
             (and (valid-insert-p tx sx sy (split-lines (access undo-rec r :data)))
                  (redo-matches-p (cdr redo)
                                  (insert-data tx sx sy (access undo-rec r :data)))))))))

(defun history-matches-p (st)
  (let ((tx (access edst st :text)))
    (and (text-p tx)
         (undo-matches-p (access edst st :undo) tx)
         (redo-matches-p (access edst st :redo) tx))))
