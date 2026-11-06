; Executes claims A, B, C and R on a small exhaustive domain, before asking for proofs.
; A failure here means a statement is false as written.  Passing proves nothing.
(in-package "ACL2")
(include-book "../statements")
(set-guard-checking :none)
(set-state-ok t)
(program)

(defconst *texts* '(((1)) (nil) ((1) nil) ((1 2) (3)) (nil nil) ((1) (2) nil)))
(defconst *repls* '(nil (7) (:nl) (7 :nl 8) (:nl :nl)))
(defconst *coords* '((0 0) (1 0) (2 0) (0 1) (1 1) (0 2) (9 0)))

(defun edits-for-repl (s es r chain coalesce)
  (if (endp es)
      nil
    (cons (list :edit (car s) (cadr s) (car (car es)) (cadr (car es)) r chain coalesce nil)
          (edits-for-repl s (cdr es) r chain coalesce))))

(defun edits-for-start (s rs chain coalesce)
  (if (endp rs)
      nil
    (append (edits-for-repl s *coords* (car rs) chain coalesce)
            (edits-for-start s (cdr rs) chain coalesce))))

(defun pairs-edits (cs es coalesce chain)
  (declare (ignorable es))
  (if (endp cs)
      nil
    (append (edits-for-start (car cs) '(nil (7) (:nl)) chain coalesce)
            (pairs-edits (cdr cs) es coalesce chain))))

(defconst *ops*
  (append (pairs-edits '((0 0) (1 0) (0 1)) nil t nil)
          (pairs-edits '((0 0) (1 0)) nil nil nil)
          (pairs-edits '((0 0)) nil nil t)
          '((:extend 1 1) (:extend 2 1) (:extend 3 2) (:undo 0) (:undo 1) (:undo 2)
            (:redo 1) (:redo 2) (:close))))

;; A much smaller alphabet for the longest sequences.
(defconst *small-ops*
  '((:edit 0 0 0 0 (7) nil t nil)
    (:edit 1 0 1 0 (7) nil t nil)
    (:edit 0 0 1 0 nil nil t nil)
    (:edit 0 0 0 1 nil nil t nil)
    (:edit 1 0 2 0 (8) nil nil nil)
    (:edit 0 1 0 1 (:nl) nil nil t)
    (:edit 0 0 1 0 (9) t nil nil)
    (:extend 2 1) (:undo 1) (:redo 1) (:close)))

(defun fail-report (what tx wants-nl ops)
  (cw "~%FAIL ~s0 tx ~x1 wants-nl ~x2 ops ~x3~%" what tx wants-nl ops))

(defun check-one (tx wants-nl ops)
  (let* ((a (claim-a tx wants-nl ops))
         (r (claim-r tx wants-nl ops))
         (b1 (claim-b tx wants-nl ops 1))
         (b2 (claim-b tx wants-nl ops 2)))
    (prog2$ (if a nil (fail-report "A" tx wants-nl ops))
    (prog2$ (if r nil (fail-report "R" tx wants-nl ops))
    (prog2$ (if b1 nil (fail-report "B1" tx wants-nl ops))
    (prog2$ (if b2 nil (fail-report "B2" tx wants-nl ops))
            (if (and a r b1 b2) 0 1)))))))

;; All sequences over OPS of length up to DEPTH.
(mutual-recursion
 (defun walk1 (tx wants-nl prefix depth all)
   (let ((f0 (check-one tx wants-nl (reverse prefix))))
     (if (zp depth)
         (mv f0 1)
       (walk-list1 tx wants-nl prefix depth all all f0 1))))
 (defun walk-list1 (tx wants-nl prefix depth ops all f n)
   (if (endp ops)
       (mv f n)
     (mv-let (f2 n2)
       (walk1 tx wants-nl (cons (car ops) prefix) (- depth 1) all)
       (walk-list1 tx wants-nl prefix depth (cdr ops) all (+ f f2) (+ n n2))))))

;; Claim C: run shapes, after a short prefix.
(defconst *runs*
  '(((0 0 0 0 (7) nil) (1 0 1 0 (8) nil))
    ((0 0 0 0 (7) nil) (1 0 1 0 (:nl) nil) (0 1 0 1 (8) nil))
    ((0 0 0 0 (7) t) (1 0 1 0 (8) nil))
    ((1 0 2 0 nil nil) (0 0 1 0 nil nil))    ; backspace
    ((0 0 1 0 nil nil) (0 0 1 0 nil nil))    ; C-d
    ((0 0 0 1 nil nil) (0 0 1 0 nil nil))
    ((1 0 1 0 (7) nil))
    ((0 0 1 0 nil nil))))

(defun check-c-runs (tx wants-nl prefix runs f n used)
  (if (endp runs)
      (mv f n used)
    (let* ((st (reached tx wants-nl prefix))
           (ok (run-ok-p st (car runs)))
           (c (claim-c tx wants-nl prefix (car runs))))
      (prog2$ (if c nil (cw "~%FAIL C tx ~x0 prefix ~x1 run ~x2~%" tx prefix (car runs)))
              (check-c-runs tx wants-nl prefix (cdr runs)
                            (if c f (+ f 1)) (+ n 1) (if ok (+ used 1) used))))))

(defun check-c-prefixes (tx wants-nl prefixes f n used)
  (if (endp prefixes)
      (mv f n used)
    (mv-let (f2 n2 u2)
      (check-c-runs tx wants-nl (car prefixes) *runs* f n used)
      (check-c-prefixes tx wants-nl (cdr prefixes) f2 n2 u2))))

(defconst *c-prefixes*
  '(nil
    ((:edit 0 0 0 0 (7) nil t nil))
    ((:edit 0 0 0 0 (7) nil t nil) (:close))
    ((:edit 0 0 0 0 (7) nil t nil) (:undo 1))
    ((:edit 0 0 1 0 nil nil nil nil))))

(defun run-all-texts (texts wants-nl depth ops f n)
  (if (endp texts)
      (mv f n)
    (mv-let (f2 n2)
      (walk1 (car texts) wants-nl nil depth ops)
      (run-all-texts (cdr texts) wants-nl depth ops (+ f f2) (+ n n2)))))

(defun run-c-texts (texts wants-nl f n used)
  (if (endp texts)
      (mv f n used)
    (mv-let (f2 n2 u2)
      (check-c-prefixes (car texts) wants-nl *c-prefixes* f n used)
      (run-c-texts (cdr texts) wants-nl f2 n2 u2))))
