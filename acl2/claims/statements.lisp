; Milestone 2: the proposed theorem statements, NOT yet proved.
;
; Each DEFCLAIM records one statement and defines an executable check of it.
; The bottom of this file runs each check on every valid case of a small domain, and
; fails certification if a statement is false there or if its hypotheses are never
; satisfied. Testing a statement this way finds mistakes in it, and proves nothing.
; After the owner approves the statements, Milestone 3 proves them as DEFTHMs.
(in-package "ACL2")

(include-book "spec")

(defmacro defclaim (name vars hyp concl)
  `(defun ,name ,vars
     (declare (xargs :mode :program))
     (if ,hyp (if ,concl :pass :fail) :skip)))

;; ------------------ Claim 1: character preservation ------------------

(defclaim insert-keeps-character-before (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (not (pos<= sx sy x y)))              ; point strictly before the insertion
  (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-x r) x)
         (equal (adj-y r) y)
         (equal (adj-ret r) 0)
         (equal (char-at x y new) (char-at x y tx))
         (equal (text-through x y new) (text-through x y tx)))))

(defclaim insert-keeps-character-after (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (not (pos<= x y sx sy)))              ; point strictly after the insertion
  (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-ret r) 0)
         (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
         (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))

(defclaim delete-keeps-character-before (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (not (pos<= sx sy x y)))              ; point strictly before the deletion
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) x)
         (equal (adj-y r) y)
         (equal (adj-ret r) 0)
         (equal (char-at x y new) (char-at x y tx))
         (equal (text-through x y new) (text-through x y tx)))))

(defclaim delete-keeps-character-after (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (pos<= ex ey x y))                    ; point at or after the deletion's end
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
         (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))

;; ------------------ Claim 2: exact boundaries ------------------

(defclaim insert-at-point-stays-before (tx sx sy ins)
  (and (valid-insert-p tx sx sy ins)
       (not (equal ins '(nil))))             ; a real insertion, point exactly at it
  (let* ((ex (insert-end-x sx ins))
         (ey (insert-end-y sy ins))
         (r (adjust-spec sx sy sx sy ex ey nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 0)
         ;; "same character" stops here: the point now names the first inserted
         ;; character, and the old character is at the end of the insertion
         (equal (char-at sx sy new) (char-at 0 0 ins))
         (equal (char-at ex ey new) (char-at sx sy tx)))))

(defclaim delete-at-start-stays (tx sx sy ex ey)
  (and (valid-delete-p tx sx sy ex ey)
       (not (and (equal sx ex) (equal sy ey))))  ; a real deletion, point at its start
  (let* ((r (adjust-spec sx sy sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 0)                   ; returns 0 though its character went
         (equal (char-at sx sy new) (char-at ex ey tx)))))

(defclaim delete-inside-clamps (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (not (pos<= x y sx sy))               ; strictly after the start
       (not (pos<= ex ey x y)))              ; strictly before the end
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 1)
         (equal (char-at sx sy new) (char-at ex ey tx)))))

(defclaim delete-at-end-clamps-but-keeps-character (tx sx sy ex ey)
  (and (valid-delete-p tx sx sy ex ey)
       (not (and (equal sx ex) (equal sy ey))))  ; a real deletion, point at its end
  (let* ((r (adjust-spec ex ey sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 1)                   ; returns 1 though its character survives
         (equal (char-at sx sy new) (char-at ex ey tx)))))

(defclaim empty-insert-changes-nothing (tx sx sy x y)
  (and (valid-insert-p tx sx sy '(nil))
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy sx sy nil)))
    (and (equal (insert-text tx sx sy '(nil)) tx)
         (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))

(defclaim empty-delete-changes-nothing (tx sx sy x y)
  (and (valid-delete-p tx sx sy sx sy)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy sx sy t)))
    (and (equal (delete-text tx sx sy sx sy) tx)
         (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))

;; Every other deletion statement fixes the return value for its own case. This one
;; states the whole rule, including points after the deletion.
(defclaim delete-return-is-exact (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx))
  (equal (adj-ret (adjust-spec x y sx sy ex ey t))
         (if (and (not (pos<= x y sx sy))    ; after the start
                  (pos<= x y ex ey))         ; at or before the end
             1
           0)))

;; ------------------ Claim 3: validity ------------------

(defclaim insert-keeps-point-valid (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil)))
    (and (text-p (insert-text tx sx sy ins))
         (valid-pos-p (adj-x r) (adj-y r) (insert-text tx sx sy ins)))))

(defclaim delete-keeps-point-valid (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy ex ey t)))
    (and (text-p (delete-text tx sx sy ex ey))
         (valid-pos-p (adj-x r) (adj-y r) (delete-text tx sx sy ex ey)))))

;; ------------------ Claim 4: arithmetic safety ------------------
;; The C-level half is guard verification of the generated functions, with
;; ADJUST-NO-OVERFLOW-P as the guard. These two connect it to the text model.

(defclaim insert-within-limits-cannot-overflow (tx sx sy ins x y imax)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (emil-limits-p tx imax)
       (emil-limits-p (insert-text tx sx sy ins) imax))
  (adjust-no-overflow-p x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil imax))

(defclaim delete-within-limits-cannot-overflow (tx sx sy ex ey x y imax)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (emil-limits-p tx imax)
       (emil-limits-p (delete-text tx sx sy ex ey) imax))
  (adjust-no-overflow-p x y sx sy ex ey t imax))

;; ------------------ Executable check on a small domain ------------------

(program)

(defun nums (n) (if (zp n) nil (cons (- n 1) (nums (- n 1)))))

;; All lists of N lengths, each below BASE
(defun add-each (a ls) (if (endp ls) nil (cons (cons a (car ls)) (add-each a (cdr ls)))))
(defun cross (as ls) (if (endp as) nil (append (add-each (car as) ls) (cross (cdr as) ls))))
(defun shapes-n (n base)
  (if (zp n) (list nil) (cross (nums base) (shapes-n (- n 1) base))))
(defun shapes (n base)
  (if (zp n) nil (append (shapes-n n base) (shapes (- n 1) base))))

;; Give characters distinct numbers, so equality means the same character
(defun new-line-ids (len id) (if (zp len) nil (cons id (new-line-ids (- len 1) (+ id 1)))))
(defun fill-shape (shape id)
  (if (endp shape) nil
    (cons (new-line-ids (car shape) id)
          (fill-shape (cdr shape) (+ id (car shape))))))
(defun fill-shapes (shapes id)
  (if (endp shapes) nil
    (cons (fill-shape (car shapes) id) (fill-shapes (cdr shapes) id))))

(defun line-positions (x y) ; x down to 0
  (if (zp x) (list (cons 0 y)) (cons (cons x y) (line-positions (- x 1) y))))
(defun positions-aux (tx y)
  (if (endp tx) nil
    (append (line-positions (len (car tx)) y) (positions-aux (cdr tx) (+ y 1)))))
(defun positions (tx) (positions-aux tx 0))

;; TALLY is an alist from claim name to (pass . skip); any :fail stops with an error.
(defun note (name res tally)
  (let* ((old (or (cdr (assoc-eq name tally)) (cons 0 0))))
    (cond ((eq res :fail) (er hard? 'statements "CLAIM FAILS: ~x0" name))
          ((eq res :pass) (put-assoc-eq name (cons (+ 1 (car old)) (cdr old)) tally))
          (t (put-assoc-eq name (cons (car old) (+ 1 (cdr old))) tally)))))

(defun check-ins-points (tx sx sy ins ps imax tally)
  (if (endp ps) tally
    (let* ((x (caar ps)) (y (cdar ps))
           (tally (note 'insert-keeps-character-before (insert-keeps-character-before tx sx sy ins x y) tally))
           (tally (note 'insert-keeps-character-after (insert-keeps-character-after tx sx sy ins x y) tally))
           (tally (note 'insert-keeps-point-valid (insert-keeps-point-valid tx sx sy ins x y) tally))
           (tally (note 'insert-within-limits-cannot-overflow (insert-within-limits-cannot-overflow tx sx sy ins x y imax) tally))
           (tally (note 'empty-insert-changes-nothing (empty-insert-changes-nothing tx sx sy x y) tally)))
      (check-ins-points tx sx sy ins (cdr ps) imax tally))))

(defun check-del-points (tx sx sy ex ey ps imax tally)
  (if (endp ps) tally
    (let* ((x (caar ps)) (y (cdar ps))
           (tally (note 'delete-keeps-character-before (delete-keeps-character-before tx sx sy ex ey x y) tally))
           (tally (note 'delete-keeps-character-after (delete-keeps-character-after tx sx sy ex ey x y) tally))
           (tally (note 'delete-inside-clamps (delete-inside-clamps tx sx sy ex ey x y) tally))
           (tally (note 'delete-return-is-exact (delete-return-is-exact tx sx sy ex ey x y) tally))
           (tally (note 'delete-keeps-point-valid (delete-keeps-point-valid tx sx sy ex ey x y) tally))
           (tally (note 'delete-within-limits-cannot-overflow (delete-within-limits-cannot-overflow tx sx sy ex ey x y imax) tally))
           (tally (note 'empty-delete-changes-nothing (empty-delete-changes-nothing tx sx sy x y) tally)))
      (check-del-points tx sx sy ex ey (cdr ps) imax tally))))

(defun check-inss (tx sx sy inss ps imaxs tally)
  (if (endp inss) tally
    (let* ((tally (note 'insert-at-point-stays-before (insert-at-point-stays-before tx sx sy (car inss)) tally))
           (tally (check-ins-points tx sx sy (car inss) ps (car imaxs) tally))
           (tally (check-ins-points tx sx sy (car inss) ps (cadr imaxs) tally)))
      (check-inss tx sx sy (cdr inss) ps imaxs tally))))

(defun check-ends (tx sx sy ends ps imaxs tally)
  (if (endp ends) tally
    (let* ((ex (caar ends)) (ey (cdar ends))
           (tally (note 'delete-at-start-stays (delete-at-start-stays tx sx sy ex ey) tally))
           (tally (note 'delete-at-end-clamps-but-keeps-character (delete-at-end-clamps-but-keeps-character tx sx sy ex ey) tally))
           (tally (check-del-points tx sx sy ex ey ps (car imaxs) tally))
           (tally (check-del-points tx sx sy ex ey ps (cadr imaxs) tally)))
      (check-ends tx sx sy (cdr ends) ps imaxs tally))))

(defun check-starts (tx starts ps inss imaxs tally)
  (if (endp starts) tally
    (let* ((sx (caar starts)) (sy (cdar starts))
           (tally (check-inss tx sx sy inss ps imaxs tally))
           (tally (check-ends tx sx sy ps ps imaxs tally)))
      (check-starts tx (cdr starts) ps inss imaxs tally))))

(defun check-texts (txs inss imaxs tally)
  (if (endp txs) tally
    (let* ((ps (positions (car txs))))
      (check-texts (cdr txs) inss imaxs
                   (check-starts (car txs) ps ps inss imaxs tally)))))

(defun check-all ()
  (check-texts (fill-shapes (shapes 3 3) 1)         ; up to 3 lines of up to 2 chars
               (fill-shapes (shapes 2 3) 100)       ; inserted text: 2 lines, 2 chars
               (list 2147483647 4)                  ; real INT_MAX and a tight small one
               nil))

(logic)

;; Every claim must pass somewhere and never fail. The tight IMAX cases can also be
;; skipped: their limit hypotheses often don't hold, which is what makes them tight.
(make-event
 (let ((tally (check-all)))
   (prog2$ (cw "~%STATEMENT-CHECK ~x0~%" tally)
           (if (and (equal (len tally) 15)
                    (not (member-equal 0 (strip-cars (strip-cdrs tally)))))
               '(value-triple :statements-checked)
             (er hard? 'statements "A claim's hypotheses were never satisfied: ~x0" tally)))))
