; Claims A, B, C and R as checkable predicates.  These are the statements for the owner
; to review.  Definitions only: nothing here has been proved.
(in-package "ACL2")

(include-book "model")

;; ---- The sequences the claims cover ----

;; One operation.  Edits and extensions may have any arguments: invalid ones are refused.
;;   (:edit sx sy ex ey repl chain coalesce burst)
;;   (:extend from n)
;;   (:undo count)  (:redo count)
;;   (:cursor x y)  (:close)
;; Not here, as assumptions: read-only changes and clearing the history.
(defun run-op (st op)
  (case (car op)
    (:edit (edit st (nth 1 op) (nth 2 op) (nth 3 op) (nth 4 op) (nth 5 op)
                 (nth 6 op) (nth 7 op) (nth 8 op)))
    (:extend (extend-rows st (nth 1 op) (nth 2 op)))
    (:undo (mv-let (r st2) (do-undo st (nth 1 op)) (declare (ignore r)) st2))
    (:redo (mv-let (r st2) (do-redo st (nth 1 op)) (declare (ignore r)) st2))
    (:cursor (change edst st :cx (nth 1 op) :cy (nth 2 op)))
    (:close (change edst st :undo (close-run (access edst st :undo))))
    (otherwise st)))

(defun run-ops (st ops)
  (declare (xargs :measure (len ops)))
  (if (endp ops)
      st
    (run-ops (run-op st (car ops)) (cdr ops))))

;; Replacement text is a true list; each row holds no newline.
(defun op-ok-p (op)
  (or (not (equal (car op) :edit))
      (true-listp (nth 5 op))))

(defun ops-ok-p (ops)
  (if (endp ops)
      (equal ops nil)
    (and (op-ok-p (car ops)) (ops-ok-p (cdr ops)))))

(defun no-newline-rows-p (tx)
  (if (endp tx)
      t
    (and (not (member-equal :nl (car tx)))
         (no-newline-rows-p (cdr tx)))))

;; The state before any edit: a text with rows, an empty history.
(defun initial-ok-p (tx)
  (and (text-p tx) (no-newline-rows-p tx)))

(defun initial-st (tx wants-nl)
  (make edst :text tx :undo nil :redo nil :cx 0 :cy 0
        :wants-nl wants-nl :read-only nil))

(defun reached (tx wants-nl ops)
  (run-ops (initial-st tx wants-nl) ops))

(defun text-of (st) (access edst st :text))

;; ---- Claim R: the history matches the text ----

;; After any sequence, undo replay's unchecked assumptions all hold.
(defun claim-r (tx wants-nl ops)
  (implies (and (initial-ok-p tx) (ops-ok-p ops))
           (history-matches-p (reached tx wants-nl ops))))

;; ---- Claim A: undoing everything restores the original ----

(defun undo-all (st)
  (mv-let (r st2)
    (do-undo st (+ 1 (len (access edst st :undo))))
    (declare (ignore r))
    st2))

(defun claim-a (tx wants-nl ops)
  (implies (and (initial-ok-p tx) (ops-ok-p ops))
           (equal (text-of (undo-all (reached tx wants-nl ops))) tx)))

;; ---- Claim B: redo after undo restores the text ----

;; If N groups could be undone, redoing N groups gets back to the text before the undo.
(defun claim-b (tx wants-nl ops n)
  (implies (and (initial-ok-p tx) (ops-ok-p ops) (posp n))
           (let ((st (reached tx wants-nl ops)))
             (mv-let (r1 st1)
               (do-undo st n)
               (or (not (equal r1 :done))
                   (mv-let (r2 st2)
                     (do-redo st1 n)
                     (and (equal r2 :done)
                          (equal (text-of st2) (text-of st)))))))))

;; ---- Claim C: a coalesced run undoes like separate edits ----

;; An edit in a run is (sx sy ex ey repl burst).
(defun run-edit (st e coalesce)
  (edit st (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e) (nth 4 e) nil coalesce (nth 5 e)))

;; The record mutateReplaceEx would push, for an edit that either only deletes or
;; only inserts; nil otherwise.
(defun run-edit-rec (st e)
  (let* ((tx (access edst st :text))
         (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e))
         (repl (nth 4 e)) (burst (nth 5 e))
         (px (access edst st :cx)) (py (access edst st :cy)))
    (if (edit-refusal st sx sy ex ey repl)
        nil
      (let ((old (region-text tx sx sy ex ey)))
        (cond ((and (consp old) (endp repl))
               (make-undo-rec sx sy ex ey t old t nil burst px py))
              ((and (endp old) (consp repl))
               (make-undo-rec sx sy (data-end-x sx repl) (data-end-y sy repl)
                              nil repl t nil burst px py))
              (t nil))))))

;; Each edit after the first folds into the record at the head.
(defun run-merges-p (st es)
  (declare (xargs :measure (len es)))
  (if (endp es)
      t
    (let ((rec (run-edit-rec st (car es)))
          (undo (access edst st :undo)))
      (and rec
           (consp undo)
           (not (equal (merge-shape (car undo) rec) :none))
           (run-merges-p (run-edit st (car es) t) (cdr es))))))

;; The run starts with an edit of one kind that doesn't fold into an earlier record,
;; then every later edit folds in.
(defun run-ok-p (st es)
  (and (consp es)
       (run-edit-rec st (car es))
       (or (endp (access edst st :undo))
           (equal (merge-shape (car (access edst st :undo))
                               (run-edit-rec st (car es)))
                  :none))
       (run-merges-p (run-edit st (car es) t) (cdr es))))

(defun run-all (st es coalesce)
  (declare (xargs :measure (len es)))
  (if (endp es)
      st
    (run-all (run-edit st (car es) coalesce) (cdr es) coalesce)))

(defun edits-ok-p (es)
  (if (endp es)
      (equal es nil)
    (and (true-listp (nth 4 (car es))) (edits-ok-p (cdr es)))))

;; Undoing the coalesced run once gives the same text as undoing the same edits, made
;; separately, once per edit.
(defun claim-c (tx wants-nl ops es)
  (implies (and (initial-ok-p tx) (ops-ok-p ops) (edits-ok-p es)
                (run-ok-p (reached tx wants-nl ops) es))
           (let ((st (reached tx wants-nl ops)))
             (mv-let (r1 c)
               (do-undo (run-all st es t) 1)
               (declare (ignore r1))
               (mv-let (r2 s)
                 (do-undo (run-all st es nil) (len es))
                 (declare (ignore r2))
                 (and (equal (text-of (run-all st es t))
                             (text-of (run-all st es nil)))
                      (equal (text-of c) (text-of s))))))))
