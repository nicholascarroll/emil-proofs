; Milestone 2: the text model and the readable spec of adjustPoint.
; No ATC and no trust tags. These are definitions only, and nothing here is a claim.
(in-package "ACL2")

;; ---- Text: a non-empty list of lines; a line is a list of characters ----

(defun lines-p (tx)
  (if (consp tx)
      (and (true-listp (car tx)) (lines-p (cdr tx)))
    (equal tx nil)))

(defun text-p (tx) (and (consp tx) (lines-p tx)))

;; A position (x,y) is valid at any character of line y or just after its last one.
(defun valid-pos-p (x y tx)
  (and (natp x) (natp y)
       (< y (len tx))
       (<= x (len (nth y tx)))))

;; Text order on positions
(defun pos<= (ax ay bx by)
  (declare (xargs :guard (and (rationalp ax) (rationalp ay) (rationalp bx) (rationalp by))))
  (or (< ay by) (and (= ay by) (<= ax bx))))

;; ---- Edits ----

;; INS is the inserted text as a non-empty list of lines, so '(nil) is empty and
;; '((a) (b)) is "a\nb".
(defun ins-lines (prefix ins suffix)
  (if (endp (cdr ins))
      (list (append prefix (car ins) suffix))
    (cons (append prefix (car ins))
          (ins-lines nil (cdr ins) suffix))))

(defun insert-text (tx sx sy ins)
  (let ((line (nth sy tx)))
    (append (take sy tx)
            (ins-lines (take sx line) ins (nthcdr sx line))
            (nthcdr (+ sy 1) tx))))

;; Where the inserted text ends, as emil's computeInsertEnd reports it
(defun insert-end-y (sy ins) (+ sy (- (len ins) 1)))
(defun insert-end-x (sx ins)
  (if (endp (cdr ins))
      (+ sx (len (car ins)))
    (len (car (last ins)))))

(defun delete-text (tx sx sy ex ey)
  (append (take sy tx)
          (list (append (take sx (nth sy tx))
                        (nthcdr ex (nth ey tx))))
          (nthcdr (+ ey 1) tx)))

(defun valid-insert-p (tx sx sy ins)
  (and (text-p tx) (valid-pos-p sx sy tx) (text-p ins)))

(defun valid-delete-p (tx sx sy ex ey)
  (and (text-p tx)
       (valid-pos-p sx sy tx)
       (valid-pos-p ex ey tx)
       (pos<= sx sy ex ey)))

;; ---- What a position refers to ----

;; The whole text in one list, with :nl between lines
(defun flat (tx)
  (if (endp (cdr tx))
      (car tx)
    (append (car tx) (cons :nl (flat (cdr tx))))))

;; How far into FLAT a position is
(defun offset (x y tx)
  (if (zp y)
      x
    (+ (len (car tx)) 1 (offset x (- y 1) (cdr tx)))))

;; The character, newline or end of text at a position
(defun char-at (x y tx)
  (let ((f (flat tx)) (o (offset x y tx)))
    (if (< o (len f)) (nth o f) :eof)))

;; Everything from a position to the end of the text
(defun text-from (x y tx) (nthcdr (offset x y tx) (flat tx)))

;; Everything from the start of the text up to and including the position
(defun text-through (x y tx) (take (+ (offset x y tx) 1) (append (flat tx) (list :eof))))

;; ---- The readable spec of adjustPoint ----

;; Returns (list new-x new-y return-value)
(defun adjust-spec (x y sx sy ex ey del)
  (let ((d (- ey sy)))
    (if del
        (cond ((pos<= x y sx sy) (list x y 0))        ; before, or at the start
              ((pos<= x y ex ey) (list sx sy 1))      ; inside, or at the end
              ((= y ey) (list (+ sx (- x ex)) sy 0))  ; after, on the end line
              (t (list x (- y d) 0)))                 ; on a later line
      (cond ((pos<= x y sx sy) (list x y 0))          ; before, or exactly at
            ((= y sy) (list (+ x (- ex sx)) (+ y d) 0)) ; after, on the insertion line
            (t (list x (+ y d) 0))))))                ; on a later line

(defun adj-x (r) (car r))
(defun adj-y (r) (cadr r))
(defun adj-ret (r) (caddr r))

;; ---- Arithmetic ----

;; IMAX stands for INT_MAX, so the claims can be tested at small values. C's int has
;; IMAX = 2147483647, and INT_MIN = -IMAX - 1 in ATC's two's complement model.
(defun in-int-p (v imax)
  (declare (xargs :guard (and (rationalp v) (rationalp imax))))
  (and (<= (- (- imax) 1) v) (<= v imax)))

;; True exactly when no operation emil's adjustPoint performs on this path overflows.
(defun adjust-no-overflow-p (x y sx sy ex ey del imax)
  (declare (xargs :guard (and (integerp x) (integerp y) (integerp sx) (integerp sy)
                              (integerp ex) (integerp ey) (integerp imax))))
  (let ((d (- ey sy)))
    (and (in-int-p d imax)
         (if del
             (cond ((pos<= x y sx sy) t)
                   ((pos<= x y ex ey) t)
                   ((= y ey) (and (in-int-p (- x ex) imax)
                                  (in-int-p (+ sx (- x ex)) imax)))
                   (t (in-int-p (- y d) imax)))
           (cond ((pos<= x y sx sy) t)
                 ((= y sy)
                  (if (= d 0)
                      (and (in-int-p (- ex sx) imax)
                           (in-int-p (+ x (- ex sx)) imax))
                    (and (in-int-p (- x sx) imax)
                         (in-int-p (+ ex (- x sx)) imax)
                         (in-int-p (+ y d) imax))))
                 (t (in-int-p (+ y d) imax)))))))

;; The limits emil's abort() checks keep on a buffer: undo.c says "row size <= INT_MAX - 1"
;; and "numrows <= INT_MAX".
(defun rows-within-p (tx imax)
  (if (endp tx)
      t
    (and (<= (len (car tx)) (- imax 1))
         (rows-within-p (cdr tx) imax))))

(defun emil-limits-p (tx imax)
  (and (natp imax)
       (<= (len tx) imax)
       (rows-within-p tx imax)))
