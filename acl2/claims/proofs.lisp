; Milestone 3: proofs of the owner-approved statements in statements.lisp.
; No ATC, no trust tags. scripts/check-statements.py confirms each DEFTHM here has exactly
; the hypothesis and conclusion approved in statements.lisp.
(in-package "ACL2")

(include-book "spec")
(local (include-book "std/lists/top" :dir :system))
(local (include-book "arithmetic/top-with-meta" :dir :system))

(local (in-theory (disable take nthcdr nth)))

;; ---------- Lists ----------

(local (defun cdr-sub (n a) (if (zp n) a (cdr-sub (- n 1) (cdr a)))))

(local (defthm my-nthcdr-append
  (implies (natp n)
           (equal (nthcdr n (append a b))
                  (if (<= n (len a))
                      (append (nthcdr n a) b)
                    (nthcdr (- n (len a)) b))))
  :hints (("Goal" :induct (cdr-sub n a) :in-theory (enable nthcdr)))))

(local (defthm my-take-append
  (implies (natp n)
           (equal (take n (append a b))
                  (if (<= n (len a))
                      (take n a)
                    (append a (take (- n (len a)) b))))) ))

;; ---------- Text structure ----------

(local (defthm text-p-cdr
  (implies (and (text-p tx) (consp (cdr tx))) (text-p (cdr tx)))))
(local (defthm lines-p-true-listp
  (implies (lines-p tx) (true-listp tx)) :rule-classes :forward-chaining))
(local (defthm text-p-true-listp
  (implies (text-p tx) (true-listp tx)) :rule-classes :forward-chaining))
(local (defthm text-p-car
  (implies (text-p tx) (true-listp (car tx)))))
(local (defthm lines-p-nth
  (implies (lines-p tx) (true-listp (nth n tx)))
  :hints (("Goal" :in-theory (enable nth)))))

(local (defun rows-before (y tx)
  (if (zp y) 0 (+ (len (car tx)) 1 (rows-before (- y 1) (cdr tx))))))

(local (defthm rows-before-nat
  (natp (rows-before y tx)) :rule-classes :type-prescription))

(local (defthm offset-is
  (implies (acl2-numberp x)
           (equal (offset x y tx) (+ x (rows-before y tx))))))

(local (defthm flat-append
  (implies (and (consp a) (consp b))
           (equal (flat (append a b))
                  (append (flat a) (cons :nl (flat b)))))))

(local (defthm flat-ins-lines
  (implies (text-p ins)
           (equal (flat (ins-lines p ins s))
                  (append p (flat ins) s)))
  :hints (("Goal" :induct (ins-lines p ins s)))))

(local (defthm ins-lines-consp
  (consp (ins-lines p ins s)) :rule-classes :type-prescription))
(local (defthm ins-lines-true
  (true-listp (ins-lines p ins s)) :rule-classes :type-prescription))

(local (defthm insert-text-step
  (implies (and (not (zp sy)) (consp tx))
           (equal (insert-text tx sx sy ins)
                  (cons (car tx) (insert-text (cdr tx) sx (- sy 1) ins))))
  :hints (("Goal" :in-theory (enable nth nthcdr take)))))
(local (defthm insert-text-base
  (implies (equal sy 0)
           (equal (insert-text tx sx sy ins)
                  (append (ins-lines (take sx (car tx)) ins (nthcdr sx (car tx)))
                          (cdr tx))))
  :hints (("Goal" :in-theory (enable nth nthcdr take)))))
(local (in-theory (disable insert-text)))

(local (defthm flat-of-insert
  (implies (and (text-p tx) (text-p ins)
                (natp sy) (< sy (len tx))
                (natp sx) (<= sx (len (nth sy tx))))
           (equal (flat (insert-text tx sx sy ins))
                  (append (take (offset sx sy tx) (flat tx))
                          (flat ins)
                          (nthcdr (offset sx sy tx) (flat tx)))))
  :hints (("Goal" :induct (cdr-sub sy tx) :in-theory (enable nth)))))

;; ---------- Offsets ----------

(local (defthm nth-of-cons-step
  (implies (and (not (zp y)))
           (equal (nth y (cons a b)) (nth (- y 1) b)))
  :hints (("Goal" :in-theory (enable nth)))))

(local (defthm offset-within-flat
  (implies (and (text-p tx) (natp y) (< y (len tx)) (natp x) (<= x (len (nth y tx))))
           (<= (+ x (rows-before y tx)) (len (flat tx))))
  :hints (("Goal" :induct (rows-before y tx) :in-theory (enable nth)))
  :rule-classes :linear))

;; A position on an earlier line is strictly earlier in the flat text
(local (defun two-sub (y b tx)
  (if (or (zp y) (zp b)) tx (two-sub (- y 1) (- b 1) (cdr tx)))))
(local (defthm earlier-line-earlier-offset
  (implies (and (natp y) (natp b) (< y b) (natp x) (<= x (len (nth y tx))))
           (< (+ x (rows-before y tx)) (rows-before b tx)))
  :hints (("Goal" :induct (two-sub y b tx) :in-theory (enable nth)
           :expand ((rows-before b tx) (rows-before y tx))))
  :rule-classes :linear))

;; Splitting rows-before at a line
(local (defthm rows-before-split
  (implies (and (natp n) (natp k))
           (equal (rows-before (+ n k) l)
                  (+ (rows-before n l) (rows-before k (nthcdr n l)))))
  :hints (("Goal" :induct (cdr-sub n l) :in-theory (enable nthcdr)))))

(local (in-theory (disable rows-before-split)))

(local (defun len-all (a) (if (endp a) 0 (+ (len (car a)) 1 (len-all (cdr a))))))
(local (defthm len-all-flat
  (implies (consp a) (equal (len-all a) (+ 1 (len (flat a)))))))
(local (defthm rows-before-append-len
  (implies (natp k)
           (equal (rows-before (+ (len a) k) (append a b))
                  (+ (len-all a) (rows-before k b))))
  :hints (("Goal" :induct (len a)))))
(local (defthm len-ins-lines
  (equal (len (ins-lines p ins s)) (if (consp (cdr ins)) (len ins) 1))))

;; ---------- Insertion: where lines end up ----------

(local (defthm ins-lines-end-column
  (implies (text-p ins)
           (equal (+ (rows-before (- (len ins) 1) (append (ins-lines p ins s) r))
                     (insert-end-x (len p) ins))
                  (+ (len p) (len (flat ins)))))
  :hints (("Goal" :induct (ins-lines p ins s)))))

(local (defthm ins-lines-end-length
  (implies (text-p ins)
           (equal (len (nth (- (len ins) 1) (append (ins-lines p ins s) r)))
                  (+ (insert-end-x (len p) ins) (len s))))
  :hints (("Goal" :induct (ins-lines p ins s) :in-theory (enable nth)))))

(local (defthm rows-before-insert-unchanged
  (implies (and (natp y) (natp sy) (<= y sy) (< sy (len tx)))
           (equal (rows-before y (insert-text tx sx sy ins))
                  (rows-before y tx)))
  :hints (("Goal" :induct (two-sub y sy tx)
           :expand ((rows-before y tx)
                    (rows-before y (cons (car tx) (insert-text (cdr tx) sx (- sy 1) ins))))))))

(local (defthm rows-before-insert-end
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)) (natp sx)
                (<= sx (len (nth sy tx))))
           (equal (+ (rows-before (insert-end-y sy ins) (insert-text tx sx sy ins))
                     (insert-end-x sx ins))
                  (+ (rows-before sy tx) sx (len (flat ins)))))
  :hints (("Goal" :induct (cdr-sub sy tx) :in-theory (enable nth))
          ("Subgoal *1/1" :use ((:instance ins-lines-end-column
                                           (p (take sx (car tx)))
                                           (s (nthcdr sx (car tx)))
                                           (r (cdr tx))))))))

(local (defthm nth-append-len
  (implies (natp k)
           (equal (nth (+ (len a) k) (append a b)) (nth k b)))
  :hints (("Goal" :induct (len a) :in-theory (enable nth)))))

(local (defthm rows-before-insert-later
  (implies (and (text-p tx) (text-p ins) (natp sy) (natp y) (< sy y) (< y (len tx))
                (natp sx) (<= sx (len (nth sy tx))))
           (equal (rows-before (+ -1 y (len ins)) (insert-text tx sx sy ins))
                  (+ (rows-before y tx) (len (flat ins)))))
  :hints (("Goal" :induct (two-sub y sy tx) :in-theory (enable nth)
           :expand ((rows-before y tx)))
          ("Subgoal *1/1" :use ((:instance rows-before-append-len
                                           (a (ins-lines (take sx (car tx)) ins (nthcdr sx (car tx))))
                                           (b (cdr tx))
                                           (k (- y 1))))))))

(local (defthm len-insert-text
  (implies (and (text-p ins) (natp sy) (< sy (len tx)) (true-listp tx))
           (equal (len (insert-text tx sx sy ins)) (+ (len tx) (len ins) -1)))
  :hints (("Goal" :induct (cdr-sub sy tx)))))

(local (defthm nth-insert-before
  (implies (and (natp y) (natp sy) (< y sy) (< sy (len tx)))
           (equal (nth y (insert-text tx sx sy ins)) (nth y tx)))
  :hints (("Goal" :induct (two-sub y sy tx) :in-theory (enable nth)))))

(local (defthm nth-insert-later
  (implies (and (text-p ins) (natp y) (natp sy) (< sy y) (< y (len tx)))
           (equal (nth (+ -1 y (len ins)) (insert-text tx sx sy ins)) (nth y tx)))
  :hints (("Goal" :induct (two-sub y sy tx) :in-theory (enable nth))
          ("Subgoal *1/1" :use ((:instance nth-append-len
                                           (a (ins-lines (take sx (car tx)) ins (nthcdr sx (car tx))))
                                           (b (cdr tx))
                                           (k (- y 1))))))))

(local (defthm len-nth-insert-end
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)) (natp sx)
                (<= sx (len (nth sy tx))))
           (equal (len (nth (insert-end-y sy ins) (insert-text tx sx sy ins)))
                  (+ (insert-end-x sx ins) (- (len (nth sy tx)) sx))))
  :hints (("Goal" :induct (cdr-sub sy tx) :in-theory (enable nth))
          ("Subgoal *1/1" :use ((:instance ins-lines-end-length
                                           (p (take sx (car tx)))
                                           (s (nthcdr sx (car tx)))
                                           (r (cdr tx))))))))

(local (defthm len-first-ins-line
  (implies (and (text-p ins) (natp sx) (<= sx (len line)))
           (<= sx (len (car (ins-lines (take sx line) ins (nthcdr sx line))))))
  :rule-classes :linear))

(local (defthm len-nth-insert-start
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)) (natp sx)
                (<= sx (len (nth sy tx))))
           (<= sx (len (nth sy (insert-text tx sx sy ins)))))
  :hints (("Goal" :induct (cdr-sub sy tx) :in-theory (enable nth)))
  :rule-classes :linear))

(local (defthm text-p-ins-lines
  (implies (and (text-p ins) (true-listp p) (true-listp s))
           (lines-p (ins-lines p ins s)))))
(local (defthm lines-p-append
  (implies (and (lines-p a) (lines-p b)) (lines-p (append a b)))))

(local (defthm insert-text-is-text
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)))
           (text-p (insert-text tx sx sy ins)))
  :hints (("Goal" :induct (cdr-sub sy tx)))))

;; ---------- Characters from the flat text ----------

(local (defthm nthcdr-car-is-nth
  (implies (natp n)
           (equal (if (< n (len f)) (nth n f) :eof)
                  (if (consp (nthcdr n f)) (car (nthcdr n f)) :eof)))
  :hints (("Goal" :induct (cdr-sub n f) :in-theory (enable nth nthcdr)))))

(local (defthm char-at-from-text-from
  (implies (natp (offset x y tx))
           (equal (char-at x y tx)
                  (if (consp (text-from x y tx)) (car (text-from x y tx)) :eof)))
  :hints (("Goal" :use ((:instance nthcdr-car-is-nth (n (offset x y tx)) (f (flat tx))))
           :in-theory (disable nthcdr-car-is-nth offset-is)))))
(local (in-theory (disable char-at-from-text-from nthcdr-car-is-nth)))

(local (defthm take-of-append-take
  (implies (and (natp n) (natp o) (<= n o) (<= o (len f)))
           (equal (take n (append (take o f) x)) (take n f)))))

(local (defthm nth-of-append-take
  (implies (and (natp n) (natp o) (< n o) (<= o (len f)))
           (equal (nth n (append (take o f) x)) (nth n f)))))

(local (defthm nthcdr-len-true-list
  (implies (true-listp x) (equal (nthcdr (len x) x) nil))
  :hints (("Goal" :induct (len x) :expand ((nthcdr (len x) x))
           :in-theory (enable nthcdr)))))

(local (defthm nthcdr-past-inserted
  (implies (and (natp n) (natp o) (<= o n) (<= o (len f)) (true-listp x))
           (equal (nthcdr (+ n (len x)) (append (take o f) x (nthcdr o f)))
                  (nthcdr n f)))
  :hints (("Goal" :in-theory (disable my-nthcdr-append)
           :use ((:instance my-nthcdr-append (n (+ n (len x))) (a (take o f))
                            (b (append x (nthcdr o f))))
                 (:instance my-nthcdr-append (n (+ n (len x) (- o))) (a x) (b (nthcdr o f))))))))

;; Line text is a true list, so the flat text is too
(local (defthm flat-true-listp
  (implies (text-p tx) (true-listp (flat tx)))
  :hints (("Goal" :induct (flat tx)))
  :rule-classes (:rewrite :type-prescription)))

;; Text order on valid positions is order of offsets
(local (defthm offset-order
  (implies (and (natp ax) (natp ay) (natp bx) (natp by)
                (<= ax (len (nth ay tx)))
                (not (pos<= bx by ax ay)))
           (< (+ ax (rows-before ay tx)) (+ bx (rows-before by tx))))
  :hints (("Goal" :cases ((< ay by) (equal ay by))
           :in-theory (e/d (pos<=) (earlier-line-earlier-offset))
           :use ((:instance earlier-line-earlier-offset (x ax) (y ay) (b by)))))
  :rule-classes :linear))

(local (in-theory (disable insert-text-step insert-text-base rows-before flat pos<=)))

(local (defthm rows-before-zero
  (implies (zp y) (equal (rows-before y tx) 0))
  :hints (("Goal" :in-theory (enable rows-before)))))

(local (defthm nthcdr-of-take-same
  (implies (natp n) (equal (nthcdr n (take n f)) nil))
  :hints (("Goal" :in-theory (enable nthcdr take)))))

;; ---------- adjust-spec, one case at a time ----------

(local (defthm pos-order-total
  (implies (and (rationalp ax) (rationalp ay) (rationalp bx) (rationalp by)
                (not (pos<= ax ay bx by)))
           (pos<= bx by ax ay))
  :hints (("Goal" :in-theory (enable pos<=)))))

(local (defthm pos-order-rows
  (implies (and (pos<= ax ay bx by) (rationalp ay) (rationalp by))
           (<= ay by))
  :hints (("Goal" :in-theory (enable pos<=)))
  :rule-classes :forward-chaining))

(local (defthm not-pos-order-rows
  (implies (and (not (pos<= bx by ax ay)) (rationalp ay) (rationalp by))
           (<= ay by))
  :hints (("Goal" :in-theory (enable pos<=)))
  :rule-classes ((:forward-chaining :trigger-terms ((pos<= bx by ax ay))))))

(local (defthm pos-same-row
  (implies (and (natp ax) (natp ay) (natp bx))
           (equal (pos<= ax ay bx ay) (<= ax bx)))
  :hints (("Goal" :in-theory (enable pos<=)))))

(local (defthm spec-at-or-before
  (implies (pos<= x y sx sy)
           (equal (adjust-spec x y sx sy ex ey del) (list x y 0)))))
(local (defthm spec-ins-on-line
  (implies (and (not (pos<= x y sx sy)) (equal y sy))
           (equal (adjust-spec x y sx sy ex ey nil)
                  (list (+ x (- ex sx)) (+ y (- ey sy)) 0)))))
(local (defthm spec-ins-later
  (implies (and (not (pos<= x y sx sy)) (not (equal y sy)) (acl2-numberp y) (acl2-numberp sy))
           (equal (adjust-spec x y sx sy ex ey nil)
                  (list x (+ y (- ey sy)) 0)))))
(local (defthm spec-del-inside
  (implies (and (not (pos<= x y sx sy)) (pos<= x y ex ey) del)
           (equal (adjust-spec x y sx sy ex ey del) (list sx sy 1)))))
(local (defthm spec-del-end-line
  (implies (and (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (equal y ey) del)
           (equal (adjust-spec x y sx sy ex ey del) (list (+ sx (- x ex)) sy 0)))))
(local (defthm spec-del-later
  (implies (and (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (not (equal y ey))
                (acl2-numberp y) (acl2-numberp ey) del)
           (equal (adjust-spec x y sx sy ex ey del)
                  (list x (- y (- ey sy)) 0)))))
(local (in-theory (disable adjust-spec)))

;; ------------------ Claim 1: character preservation (insertion) ------------------

(defthm insert-keeps-character-before
  (implies
   (and (valid-insert-p tx sx sy ins)
        (valid-pos-p x y tx)
        (not (pos<= sx sy x y)))
   (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
          (new (insert-text tx sx sy ins)))
     (and (equal (adj-x r) x)
          (equal (adj-y r) y)
          (equal (adj-ret r) 0)
          (equal (char-at x y new) (char-at x y tx))
          (equal (text-through x y new) (text-through x y tx))))))

;; Facts about the end of an insertion, in the forms the claims need
(local (defthm natp-insert-end-x
  (implies (and (natp sx) (consp ins))
           (natp (insert-end-x sx ins)))
  :rule-classes :type-prescription))
(local (defthm insert-end-x-floor
  (implies (and (natp sx) (not (consp (cdr ins))))
           (>= (insert-end-x sx ins) sx))
  :rule-classes :linear))
(local (defthm rows-before-insert-end-rw
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)) (natp sx)
                (<= sx (len (nth sy tx))))
           (equal (rows-before (insert-end-y sy ins) (insert-text tx sx sy ins))
                  (+ (rows-before sy tx) sx (len (flat ins)) (- (insert-end-x sx ins)))))
  :hints (("Goal" :use rows-before-insert-end :in-theory (disable rows-before-insert-end)))))
(local (in-theory (disable insert-end-y insert-end-x rows-before-insert-end char-at text-from)))

(defthm insert-keeps-character-after
  (implies
   (and (valid-insert-p tx sx sy ins)
        (valid-pos-p x y tx)
        (not (pos<= x y sx sy)))
   (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
          (new (insert-text tx sx sy ins)))
     (and (equal (adj-ret r) 0)
          (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
          (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))
  :hints (("Goal" :cases ((equal y sy))
           :in-theory (enable char-at-from-text-from text-from)
           :use ((:instance nthcdr-past-inserted
                            (n (+ x (rows-before y tx)))
                            (o (+ sx (rows-before sy tx)))
                            (f (flat tx))
                            (x (flat ins)))
                 (:instance offset-order (ax sx) (ay sy) (bx x) (by y))))
          ("Subgoal 2" :in-theory (enable char-at-from-text-from text-from insert-end-y))))

(local (defthm pos-reflexive
  (implies (and (acl2-numberp x) (acl2-numberp y) (rationalp x)) (pos<= x y x y))
  :hints (("Goal" :in-theory (enable pos<=)))))

(local (defthm consp-flat-nonempty
  (implies (and (text-p ins) (not (equal ins '(nil))))
           (consp (flat ins)))
  :hints (("Goal" :in-theory (enable flat) :expand ((flat ins))))))

(local (defthm car-flat-is-first
  (equal (char-at 0 0 ins)
         (if (consp (flat ins)) (car (flat ins)) :eof))
  :hints (("Goal" :in-theory (enable char-at-from-text-from text-from)))))

;; ------------------ Claim 2: exact boundaries (insertion) ------------------

(defthm insert-at-point-stays-before
  (implies
   (and (valid-insert-p tx sx sy ins)
        (not (equal ins '(nil))))
   (let* ((ex (insert-end-x sx ins))
          (ey (insert-end-y sy ins))
          (r (adjust-spec sx sy sx sy ex ey nil))
          (new (insert-text tx sx sy ins)))
     (and (equal (adj-x r) sx)
          (equal (adj-y r) sy)
          (equal (adj-ret r) 0)
          (equal (char-at sx sy new) (char-at 0 0 ins))
          (equal (char-at ex ey new) (char-at sx sy tx)))))
  :hints (("Goal" :in-theory (enable char-at-from-text-from text-from)
           :use ((:instance nthcdr-past-inserted
                            (n (+ sx (rows-before sy tx)))
                            (o (+ sx (rows-before sy tx)))
                            (f (flat tx))
                            (x (flat ins)))))))

(local (defthm insert-empty-identity
  (implies (and (text-p tx) (natp sy) (< sy (len tx)) (natp sx) (<= sx (len (nth sy tx))))
           (equal (insert-text tx sx sy '(nil)) tx))
  :hints (("Goal" :induct (cdr-sub sy tx)
           :in-theory (enable nth insert-text-step insert-text-base)))))

(defthm empty-insert-changes-nothing
  (implies
   (and (valid-insert-p tx sx sy '(nil))
        (valid-pos-p x y tx))
   (let ((r (adjust-spec x y sx sy sx sy nil)))
     (and (equal (insert-text tx sx sy '(nil)) tx)
          (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))
  :hints (("Goal" :in-theory (enable adjust-spec pos<=))))

;; ------------------ Claim 3: validity (insertion) ------------------

(local (defthm insert-before-still-fits
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx)) (natp sx)
                (<= sx (len (nth sy tx)))
                (natp x) (natp y) (<= x (len (nth y tx)))
                (pos<= x y sx sy))
           (<= x (len (nth y (insert-text tx sx sy ins)))))
  :hints (("Goal" :cases ((< y sy)) :in-theory (enable pos<=)
           :use ((:instance len-nth-insert-start))))
  :rule-classes :linear))

(local (defthm insert-end-row-bound
  (implies (and (text-p ins) (natp sy))
           (equal (insert-end-y sy ins) (+ sy (- (len ins) 1))))
  :hints (("Goal" :in-theory (enable insert-end-y)))
  :rule-classes nil))

(local (defthm valid-insert-before
  (implies (and (valid-insert-p tx sx sy ins) (valid-pos-p x y tx) (pos<= x y sx sy))
           (valid-pos-p (adj-x (adjust-spec x y sx sy ex ey nil))
                        (adj-y (adjust-spec x y sx sy ex ey nil))
                        (insert-text tx sx sy ins)))
  :hints (("Goal" :use ((:instance pos-order-rows (ax x) (ay y) (bx sx) (by sy)))))))

(local (defthm valid-insert-on-line
  (implies (and (valid-insert-p tx sx sy ins) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (equal y sy))
           (valid-pos-p (adj-x (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
                        (adj-y (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
                        (insert-text tx sx sy ins)))
  :hints (("Goal" :use ((:instance insert-end-row-bound))))))

(local (defthm valid-insert-later
  (implies (and (valid-insert-p tx sx sy ins) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (not (equal y sy)))
           (valid-pos-p (adj-x (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
                        (adj-y (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
                        (insert-text tx sx sy ins)))
  :hints (("Goal" :in-theory (enable insert-end-y)))))

(local (defthm valid-insert-gives-text
  (implies (valid-insert-p tx sx sy ins)
           (text-p (insert-text tx sx sy ins)))))

(defthm insert-keeps-point-valid
  (implies
   (and (valid-insert-p tx sx sy ins)
        (valid-pos-p x y tx))
   (let ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil)))
     (and (text-p (insert-text tx sx sy ins))
          (valid-pos-p (adj-x r) (adj-y r) (insert-text tx sx sy ins)))))
  :hints (("Goal" :in-theory (disable valid-pos-p valid-insert-p adj-x adj-y
                                      valid-insert-before valid-insert-on-line valid-insert-later)
           :use ((:instance valid-insert-before (ex (insert-end-x sx ins)) (ey (insert-end-y sy ins)))
                 valid-insert-on-line valid-insert-later))))

;; ---------- Deletion: structure ----------

(local (in-theory (enable flat rows-before)))

(local (defthm delete-text-step
  (implies (and (not (zp sy)) (not (zp ey)) (consp tx))
           (equal (delete-text tx sx sy ex ey)
                  (cons (car tx) (delete-text (cdr tx) sx (- sy 1) ex (- ey 1)))))
  :hints (("Goal" :in-theory (enable nth nthcdr take)))))
(local (defthm delete-text-base
  (implies (equal sy 0)
           (equal (delete-text tx sx sy ex ey)
                  (cons (append (take sx (car tx)) (nthcdr ex (nth ey tx)))
                        (nthcdr (+ ey 1) tx))))
  :hints (("Goal" :in-theory (enable nth nthcdr take)))))
(local (in-theory (disable delete-text)))

(local (defthm nthcdr-plus-one
  (implies (natp k) (equal (nthcdr (+ 1 k) l) (nthcdr k (cdr l))))
  :hints (("Goal" :in-theory (enable nthcdr)))))

(local (defthm nthcdr-past-line
  (implies (natp k)
           (equal (nthcdr (+ 1 (len a) k) (append a (cons b f))) (nthcdr k f)))
  :hints (("Goal" :induct (len a) :in-theory (disable nthcdr-of-cdr)))
  :rule-classes nil))

(local (defthm nthcdr-offset-flat
  (implies (and (text-p tx) (natp ey) (< ey (len tx)) (natp ex) (<= ex (len (nth ey tx))))
           (equal (nthcdr (+ ex (rows-before ey tx)) (flat tx))
                  (if (consp (nthcdr (+ ey 1) tx))
                      (append (nthcdr ex (nth ey tx))
                              (cons :nl (flat (nthcdr (+ ey 1) tx))))
                    (nthcdr ex (nth ey tx)))))
  :hints (("Goal" :induct (cdr-sub ey tx)
           :in-theory (e/d (nth) (nthcdr-of-cdr)))
          ("Subgoal *1/2" :use ((:instance nthcdr-past-line
                                           (a (car tx)) (b :nl) (f (flat (cdr tx)))
                                           (k (+ ex (rows-before (- ey 1) (cdr tx))))))))))

(local (defthm natp-offset
  (implies (and (natp x)) (natp (offset x y tx)))
  :hints (("Goal" :in-theory (disable offset-is)))
  :rule-classes :type-prescription))

(local (defthm take-offset-step
  (implies (and (not (zp y)) (consp (cdr tx)) (natp x))
           (equal (take (offset x y tx) (flat tx))
                  (append (car tx) (cons :nl (take (offset x (- y 1) (cdr tx)) (flat (cdr tx)))))))
  :hints (("Goal" :expand ((offset x y tx) (flat tx))
           :in-theory (disable offset-is)))))

(local (defthm nthcdr-offset-step
  (implies (and (not (zp y)) (consp (cdr tx)) (natp (offset x (- y 1) (cdr tx))))
           (equal (nthcdr (offset x y tx) (flat tx))
                  (nthcdr (offset x (- y 1) (cdr tx)) (flat (cdr tx)))))
  :hints (("Goal" :expand ((offset x y tx) (flat tx))
           :in-theory (disable offset-is nthcdr-plus-one nthcdr-of-cdr)
           :use ((:instance nthcdr-past-line (a (car tx)) (b :nl) (f (flat (cdr tx)))
                            (k (offset x (- y 1) (cdr tx)))))))))

(local (defthm flat-of-delete-base
  (implies (and (text-p tx) (natp sx) (<= sx (len (car tx)))
                (natp ey) (< ey (len tx)) (natp ex) (<= ex (len (nth ey tx))))
           (equal (flat (delete-text tx sx 0 ex ey))
                  (append (take sx (flat tx))
                          (nthcdr (offset ex ey tx) (flat tx)))))
  :hints (("Goal" :in-theory (disable nthcdr-plus-one nthcdr-of-cdr)))))

(local (defthm consp-delete-text
  (implies (and (natp sy) (natp ey) (<= sy ey) (consp tx))
           (consp (delete-text tx sx sy ex ey)))
  :hints (("Goal" :in-theory (enable delete-text)))
  :rule-classes :type-prescription))

(local (defthm flat-of-delete-gen
  (implies (and (text-p tx) (natp sy) (natp ey) (<= sy ey) (< ey (len tx))
                (natp sx) (<= sx (len (nth sy tx)))
                (natp ex) (<= ex (len (nth ey tx))))
           (equal (flat (delete-text tx sx sy ex ey))
                  (append (take (offset sx sy tx) (flat tx))
                          (nthcdr (offset ex ey tx) (flat tx)))))
  :hints (("Goal" :induct (two-sub sy ey tx)
           :in-theory (e/d (nth) (offset-is nthcdr-plus-one nthcdr-of-cdr flat-of-delete-base)))
          ("Subgoal *1/1" :use ((:instance flat-of-delete-base))
           :in-theory (e/d (nth) (nthcdr-plus-one nthcdr-of-cdr flat-of-delete-base))))))

(local (defthm flat-of-delete
  (implies (valid-delete-p tx sx sy ex ey)
           (equal (flat (delete-text tx sx sy ex ey))
                  (append (take (offset sx sy tx) (flat tx))
                          (nthcdr (offset ex ey tx) (flat tx)))))
  :hints (("Goal" :in-theory (e/d (pos<=) (offset-is flat-of-delete-gen))
           :use flat-of-delete-gen))))

(local (in-theory (disable nthcdr-plus-one)))

(local (defthm rows-before-next
  (implies (and (natp y) (< y (len tx)))
           (equal (rows-before (+ 1 y) tx)
                  (+ (rows-before y tx) (len (nth y tx)) 1)))
  :hints (("Goal" :induct (cdr-sub y tx) :in-theory (enable nth)))))

(local (defun three-sub (sy ey y tx)
  (if (or (zp sy) (zp ey) (zp y)) tx (three-sub (- sy 1) (- ey 1) (- y 1) (cdr tx)))))

(local (defthm rows-before-delete-unchanged
  (implies (and (natp y) (natp sy) (natp ey) (<= y sy) (<= sy ey) (< ey (len tx)))
           (equal (rows-before y (delete-text tx sx sy ex ey))
                  (rows-before y tx)))
  :hints (("Goal" :induct (three-sub sy ey y tx)))))

(local (defthm len-delete-text
  (implies (and (natp sy) (natp ey) (<= sy ey) (< ey (len tx)))
           (equal (len (delete-text tx sx sy ex ey)) (+ (len tx) sy (- ey))))
  :hints (("Goal" :induct (two-sub sy ey tx)))))

(local (defthm nth-delete-before
  (implies (and (natp y) (natp sy) (natp ey) (< y sy) (<= sy ey) (< ey (len tx)))
           (equal (nth y (delete-text tx sx sy ex ey)) (nth y tx)))
  :hints (("Goal" :induct (three-sub sy ey y tx) :in-theory (enable nth)))))

(local (defthm len-nth-delete-start
  (implies (and (natp sy) (natp ey) (<= sy ey) (< ey (len tx)) (natp sx)
                (<= sx (len (nth sy tx))) (natp ex) (<= ex (len (nth ey tx))))
           (equal (len (nth sy (delete-text tx sx sy ex ey)))
                  (+ sx (len (nth ey tx)) (- ex))))
  :hints (("Goal" :induct (two-sub sy ey tx) :in-theory (enable nth)))))

(local (defthm nth-of-nthcdr-plus
  (implies (and (natp k) (natp n))
           (equal (nth k (nthcdr n l)) (nth (+ k n) l)))
  :hints (("Goal" :induct (cdr-sub n l) :in-theory (enable nth nthcdr)))))

(local (defthm nth-delete-later
  (implies (and (natp y) (natp sy) (natp ey) (< ey y) (<= sy ey) (< y (len tx)))
           (equal (nth (+ (- ey) sy y) (delete-text tx sx sy ex ey)) (nth y tx)))
  :hints (("Goal" :induct (three-sub sy ey y tx) :in-theory (enable nth)))))

(local (defthm rows-before-delete-later
  (implies (and (text-p tx) (natp y) (natp sy) (natp ey) (< ey y) (<= sy ey) (< y (len tx))
                (natp sx) (<= sx (len (nth sy tx))) (natp ex) (<= ex (len (nth ey tx))))
           (equal (rows-before (+ (- ey) sy y) (delete-text tx sx sy ex ey))
                  (+ (rows-before y tx) sx (rows-before sy tx) (- ex) (- (rows-before ey tx)))))
  :hints (("Goal" :induct (three-sub sy ey y tx) :in-theory (enable nth))
          ("Subgoal *1/1" :use ((:instance rows-before-split (n (+ 1 ey)) (k (- y (+ 1 ey))) (l tx)))))))

(local (defthm text-p-nthcdr
  (implies (lines-p tx) (lines-p (nthcdr n tx)))
  :hints (("Goal" :induct (cdr-sub n tx) :in-theory (enable nthcdr)))))

(local (defthm delete-text-is-text
  (implies (and (text-p tx) (natp sy) (natp ey) (<= sy ey) (< ey (len tx)))
           (text-p (delete-text tx sx sy ex ey)))
  :hints (("Goal" :induct (two-sub sy ey tx)))))

(local (in-theory (disable flat rows-before delete-text-step delete-text-base
                           nthcdr-offset-flat flat-of-delete-base flat-of-delete-gen
                           take-offset-step nthcdr-offset-step)))

;; ---------- Deletion: offsets ----------

(local (defthm offset-monotone
  (implies (and (natp ax) (natp ay) (natp bx) (natp by)
                (<= ax (len (nth ay tx)))
                (pos<= ax ay bx by))
           (<= (+ ax (rows-before ay tx)) (+ bx (rows-before by tx))))
  :hints (("Goal" :do-not-induct t :cases ((< ay by) (equal ay by))
           :in-theory (e/d (pos<=) (earlier-line-earlier-offset))
           :use ((:instance earlier-line-earlier-offset (x ax) (y ay) (b by)))))
  :rule-classes :linear))

(local (defthm pos-antisymmetric
  (implies (and (pos<= ax ay bx by) (pos<= bx by ax ay)
                (rationalp ax) (rationalp ay) (rationalp bx) (rationalp by))
           (and (equal ax bx) (equal ay by)))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=)))
  :rule-classes nil))

(local (defthm nthcdr-past-deleted
  (implies (and (natp n) (natp os) (natp oe) (<= os oe) (<= oe n) (<= os (len f)))
           (equal (nthcdr (+ n os (- oe)) (append (take os f) (nthcdr oe f)))
                  (nthcdr n f)))
  :hints (("Goal" :do-not-induct t :use ((:instance my-nthcdr-append (n (+ n os (- oe))) (a (take os f))
                                   (b (nthcdr oe f))))))))

(local (defthm valid-delete-offsets
  (implies (valid-delete-p tx sx sy ex ey)
           (and (natp (+ sx (rows-before sy tx)))
                (natp (+ ex (rows-before ey tx)))
                (<= (+ sx (rows-before sy tx)) (+ ex (rows-before ey tx)))
                (<= (+ sx (rows-before sy tx)) (len (flat tx)))
                (<= (+ ex (rows-before ey tx)) (len (flat tx)))))
  :hints (("Goal" :do-not-induct t :use ((:instance offset-monotone (ax sx) (ay sy) (bx ex) (by ey))
                        (:instance offset-within-flat (x sx) (y sy))
                        (:instance offset-within-flat (x ex) (y ey)))))
  :rule-classes nil))

;; The start of a deletion now names whatever was at its end
(local (defthm text-from-delete-start
  (implies (valid-delete-p tx sx sy ex ey)
           (equal (text-from sx sy (delete-text tx sx sy ex ey))
                  (text-from ex ey tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable text-from)
           :use ((:instance valid-delete-offsets)
                 (:instance nthcdr-past-deleted
                            (n (+ ex (rows-before ey tx)))
                            (os (+ sx (rows-before sy tx)))
                            (oe (+ ex (rows-before ey tx)))
                            (f (flat tx))))))))

(local (defthm char-at-delete-start
  (implies (valid-delete-p tx sx sy ex ey)
           (equal (char-at sx sy (delete-text tx sx sy ex ey))
                  (char-at ex ey tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable char-at-from-text-from)))))

;; ------------------ Claim 1: character preservation (deletion) ------------------

(defthm delete-keeps-character-before
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx)
        (not (pos<= sx sy x y)))
   (let* ((r (adjust-spec x y sx sy ex ey t))
          (new (delete-text tx sx sy ex ey)))
     (and (equal (adj-x r) x)
          (equal (adj-y r) y)
          (equal (adj-ret r) 0)
          (equal (char-at x y new) (char-at x y tx))
          (equal (text-through x y new) (text-through x y tx)))))
  :hints (("Goal" :do-not-induct t :in-theory (enable char-at)
           :use ((:instance offset-order (ax x) (ay y) (bx sx) (by sy))
                 (:instance offset-within-flat (x sx) (y sy))))))

(local (defthm del-after-empty
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (pos<= ex ey x y) (pos<= x y sx sy))
           (and (equal (text-from (adj-x (adjust-spec x y sx sy ex ey t))
                                  (adj-y (adjust-spec x y sx sy ex ey t))
                                  (delete-text tx sx sy ex ey))
                       (text-from x y tx))))
  :hints (("Goal" :do-not-induct t :use ((:instance pos-antisymmetric (ax ex) (ay ey) (bx x) (by y))
                        (:instance pos-antisymmetric (ax sx) (ay sy) (bx x) (by y)))))))

(local (defthm del-after-at-end
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (pos<= ex ey x y) (not (pos<= x y sx sy)) (pos<= x y ex ey))
           (equal (text-from (adj-x (adjust-spec x y sx sy ex ey t))
                             (adj-y (adjust-spec x y sx sy ex ey t))
                             (delete-text tx sx sy ex ey))
                  (text-from x y tx)))
  :hints (("Goal" :do-not-induct t :use ((:instance pos-antisymmetric (ax ex) (ay ey) (bx x) (by y)))))))

(local (defthm del-after-end-line
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (equal y ey))
           (equal (text-from (adj-x (adjust-spec x y sx sy ex ey t))
                             (adj-y (adjust-spec x y sx sy ex ey t))
                             (delete-text tx sx sy ex ey))
                  (text-from x y tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable text-from)
           :use ((:instance valid-delete-offsets)
                 (:instance offset-order (ax ex) (ay ey) (bx x) (by y))
                 (:instance nthcdr-past-deleted
                            (n (+ x (rows-before y tx)))
                            (os (+ sx (rows-before sy tx)))
                            (oe (+ ex (rows-before ey tx)))
                            (f (flat tx))))))))

(local (defthm del-after-later
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (not (equal y ey)))
           (equal (text-from (adj-x (adjust-spec x y sx sy ex ey t))
                             (adj-y (adjust-spec x y sx sy ex ey t))
                             (delete-text tx sx sy ex ey))
                  (text-from x y tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable text-from)
           :use ((:instance valid-delete-offsets)
                 (:instance offset-order (ax ex) (ay ey) (bx x) (by y))
                 (:instance nthcdr-past-deleted
                            (n (+ x (rows-before y tx)))
                            (os (+ sx (rows-before sy tx)))
                            (oe (+ ex (rows-before ey tx)))
                            (f (flat tx))))))))

(local (defthm del-after-text-from
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx) (pos<= ex ey x y))
           (equal (text-from (adj-x (adjust-spec x y sx sy ex ey t))
                             (adj-y (adjust-spec x y sx sy ex ey t))
                             (delete-text tx sx sy ex ey))
                  (text-from x y tx)))
  :hints (("Goal" :do-not-induct t :in-theory (disable valid-delete-p valid-pos-p adj-x adj-y
                                      del-after-empty del-after-at-end del-after-end-line del-after-later)
           :use (del-after-empty del-after-at-end del-after-end-line del-after-later)))))

;; Adjusted positions are never negative
(local (defthm natp-adjusted-delete
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx))
           (and (natp (adj-x (adjust-spec x y sx sy ex ey t)))
                (natp (adj-y (adjust-spec x y sx sy ex ey t)))))
  :hints (("Goal" :do-not-induct t :in-theory (enable adjust-spec pos<=)))))

(local (defthm valid-pos-natp
  (implies (valid-pos-p x y tx) (natp x))
  :rule-classes :forward-chaining))

(defthm delete-keeps-character-after
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx)
        (pos<= ex ey x y))
   (let* ((r (adjust-spec x y sx sy ex ey t))
          (new (delete-text tx sx sy ex ey)))
     (and (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
          (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (char-at-from-text-from)
                                  (adj-x adj-y valid-pos-p valid-delete-p text-from offset-is
                                         natp-adjusted-delete del-after-text-from))
           :use (natp-adjusted-delete del-after-text-from
                 (:instance natp-offset (x (adj-x (adjust-spec x y sx sy ex ey t)))
                            (y (adj-y (adjust-spec x y sx sy ex ey t)))
                            (tx (delete-text tx sx sy ex ey)))
                 (:instance natp-offset)))))

;; ------------------ Claim 2: exact boundaries (deletion) ------------------

(defthm delete-at-start-stays
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (not (and (equal sx ex) (equal sy ey))))
   (let* ((r (adjust-spec sx sy sx sy ex ey t))
          (new (delete-text tx sx sy ex ey)))
     (and (equal (adj-x r) sx)
          (equal (adj-y r) sy)
          (equal (adj-ret r) 0)
          (equal (char-at sx sy new) (char-at ex ey tx))))))

(defthm delete-inside-clamps
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx)
        (not (pos<= x y sx sy))
        (not (pos<= ex ey x y)))
   (let* ((r (adjust-spec x y sx sy ex ey t))
          (new (delete-text tx sx sy ex ey)))
     (and (equal (adj-x r) sx)
          (equal (adj-y r) sy)
          (equal (adj-ret r) 1)
          (equal (char-at sx sy new) (char-at ex ey tx))))))

(defthm delete-at-end-clamps-but-keeps-character
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (not (and (equal sx ex) (equal sy ey))))
   (let* ((r (adjust-spec ex ey sx sy ex ey t))
          (new (delete-text tx sx sy ex ey)))
     (and (equal (adj-x r) sx)
          (equal (adj-y r) sy)
          (equal (adj-ret r) 1)
          (equal (char-at sx sy new) (char-at ex ey tx)))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance pos-antisymmetric (ax ex) (ay ey) (bx sx) (by sy))))))

(defthm delete-return-is-exact
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx))
   (equal (adj-ret (adjust-spec x y sx sy ex ey t))
          (if (and (not (pos<= x y sx sy))
                   (pos<= x y ex ey))
              1
            0)))
  :hints (("Goal" :do-not-induct t :in-theory (enable adjust-spec))))

(local (defthm delete-empty-identity
  (implies (and (text-p tx) (natp sy) (< sy (len tx)) (natp sx) (<= sx (len (nth sy tx))))
           (equal (delete-text tx sx sy sx sy) tx))
  :hints (("Goal" :induct (cdr-sub sy tx)
           :in-theory (enable nth delete-text-step delete-text-base)))))

(defthm empty-delete-changes-nothing
  (implies
   (and (valid-delete-p tx sx sy sx sy)
        (valid-pos-p x y tx))
   (let ((r (adjust-spec x y sx sy sx sy t)))
     (and (equal (delete-text tx sx sy sx sy) tx)
          (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))
  :hints (("Goal" :do-not-induct t :in-theory (enable adjust-spec pos<=))))

;; ------------------ Claim 3: validity (deletion) ------------------

(local (defthm valid-delete-before
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx) (pos<= x y sx sy))
           (valid-pos-p (adj-x (adjust-spec x y sx sy ex ey t))
                        (adj-y (adjust-spec x y sx sy ex ey t))
                        (delete-text tx sx sy ex ey)))
  :hints (("Goal" :do-not-induct t :cases ((< y sy))
           :in-theory (enable pos<=)))))

(local (defthm valid-delete-inside
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (pos<= x y ex ey))
           (valid-pos-p (adj-x (adjust-spec x y sx sy ex ey t))
                        (adj-y (adjust-spec x y sx sy ex ey t))
                        (delete-text tx sx sy ex ey)))))

(local (defthm valid-delete-end-line
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (equal y ey))
           (valid-pos-p (adj-x (adjust-spec x y sx sy ex ey t))
                        (adj-y (adjust-spec x y sx sy ex ey t))
                        (delete-text tx sx sy ex ey)))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=)))))

(local (defthm nth-delete-later-same-row
  (implies (and (natp y) (natp ey) (< ey y) (< y (len tx)))
           (equal (nth y (delete-text tx sx ey ex ey)) (nth y tx)))
  :hints (("Goal" :do-not-induct t
           :use ((:instance nth-delete-later (sy ey)))))))

(local (defthm valid-delete-later
  (implies (and (valid-delete-p tx sx sy ex ey) (valid-pos-p x y tx)
                (not (pos<= x y sx sy)) (not (pos<= x y ex ey)) (not (equal y ey)))
           (valid-pos-p (adj-x (adjust-spec x y sx sy ex ey t))
                        (adj-y (adjust-spec x y sx sy ex ey t))
                        (delete-text tx sx sy ex ey)))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=)
           :use ((:instance nth-delete-later))))))

(local (defthm valid-delete-gives-text
  (implies (valid-delete-p tx sx sy ex ey)
           (text-p (delete-text tx sx sy ex ey)))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (pos<=) (delete-text-is-text))
           :use delete-text-is-text))))

(defthm delete-keeps-point-valid
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx))
   (let ((r (adjust-spec x y sx sy ex ey t)))
     (and (text-p (delete-text tx sx sy ex ey))
          (valid-pos-p (adj-x r) (adj-y r) (delete-text tx sx sy ex ey)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable valid-pos-p valid-delete-p adj-x adj-y
                               valid-delete-before valid-delete-inside valid-delete-end-line
                               valid-delete-later)
           :use (valid-delete-before valid-delete-inside valid-delete-end-line valid-delete-later))))

;; ------------------ Claim 4: arithmetic safety ------------------

(defthm no-overflow-predicate-is-satisfiable
  (adjust-no-overflow-p 0 0 0 0 0 0 nil 2147483647))

(defthm half-range-cannot-overflow
  (implies
   (and (natp imax)
        (natp x) (natp y) (natp sx) (natp sy) (natp ex) (natp ey)
        (<= (* 2 x) imax) (<= (* 2 y) imax)
        (<= (* 2 sx) imax) (<= (* 2 sy) imax)
        (<= (* 2 ex) imax) (<= (* 2 ey) imax))
   (adjust-no-overflow-p x y sx sy ex ey del imax))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=))))

(local (defthm rows-within-nth
  (implies (and (rows-within-p tx imax) (natp y) (< y (len tx)))
           (<= (len (nth y tx)) (- imax 1)))
  :hints (("Goal" :induct (cdr-sub y tx) :in-theory (enable nth)))
  :rule-classes nil))

(local (defthm lines-p-nonempty
  (implies (and (lines-p a) a) (and (consp a) (<= 1 (len a))))
  :rule-classes ((:linear :corollary (implies (and (lines-p a) a) (<= 1 (len a))))
                 (:forward-chaining :corollary (implies (and (lines-p a) a) (consp a))))))

(local (defthm insert-end-facts
  (implies (and (valid-insert-p tx sx sy ins)
                (emil-limits-p (insert-text tx sx sy ins) imax))
           (and (natp (insert-end-y sy ins))
                (< (insert-end-y sy ins) imax)
                (<= (+ (insert-end-x sx ins) (- (len (nth sy tx)) sx)) (- imax 1))))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (insert-end-y) (len-nth-insert-end))
           :use (len-nth-insert-end
                 (:instance rows-within-nth (y (insert-end-y sy ins))
                            (tx (insert-text tx sx sy ins))))))
  :rule-classes nil))

(local (defthm insert-end-x-single
  (implies (and (natp sx) (consp ins) (not (consp (cdr ins))))
           (<= sx (insert-end-x sx ins)))
  :hints (("Goal" :in-theory (enable insert-end-x)))
  :rule-classes :linear))

(local (defthm insert-end-y-same-means-single
  (implies (and (consp ins) (true-listp ins) (equal (insert-end-y sy ins) sy) (acl2-numberp sy))
           (not (consp (cdr ins))))
  :hints (("Goal" :in-theory (enable insert-end-y)))
  :rule-classes nil))

(defthm insert-within-limits-cannot-overflow
  (implies
   (and (valid-insert-p tx sx sy ins)
        (valid-pos-p x y tx)
        (emil-limits-p tx imax)
        (emil-limits-p (insert-text tx sx sy ins) imax))
   (adjust-no-overflow-p x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil imax))
  :hints (("Goal" :do-not-induct t
           :in-theory (enable insert-end-y pos<=)
           :use (insert-end-facts
                 insert-end-y-same-means-single
                 (:instance rows-within-nth (y y))
                 (:instance rows-within-nth (y (+ -1 y (len ins)))
                            (tx (insert-text tx sx sy ins)))))))

(local (defthm delete-start-row-bound
  (implies (and (valid-delete-p tx sx sy ex ey)
                (emil-limits-p (delete-text tx sx sy ex ey) imax))
           (<= (+ sx (len (nth ey tx)) (- ex)) (- imax 1)))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (pos<=) (len-nth-delete-start))
           :use (len-nth-delete-start
                 (:instance rows-within-nth (y sy) (tx (delete-text tx sx sy ex ey))))))
  :rule-classes nil))

(defthm delete-within-limits-cannot-overflow
  (implies
   (and (valid-delete-p tx sx sy ex ey)
        (valid-pos-p x y tx)
        (emil-limits-p tx imax)
        (emil-limits-p (delete-text tx sx sy ex ey) imax))
   (adjust-no-overflow-p x y sx sy ex ey t imax))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=)
           :use (delete-start-row-bound
                 (:instance rows-within-nth (y y))
                 (:instance rows-within-nth (y ey))))))
