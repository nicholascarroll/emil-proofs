; Text-level lemmas for the undo proofs.  Nothing here is a claim in itself.
; Everything reduces to the flat text: two clean texts are equal when their flat forms are,
; and a position is an offset into the flat text.
; Copied from acl2/claims/proofs.lisp, where these are local: list, offset and flat lemmas.
(in-package "ACL2")

(include-book "statements")
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

;; ---------- Flat is one-to-one on clean text ----------

(defun clean-p (tx) (and (text-p tx) (no-newline-rows-p tx)))

(local (defun no-nl-p (l)
  (if (endp l) t (and (not (equal (car l) :nl)) (no-nl-p (cdr l))))))

(local (defthm member-is-no-nl
  (iff (member-equal :nl l) (not (no-nl-p l)))))

(local (defthm split-lines-no-nl-append
  (implies (no-nl-p a)
           (equal (split-lines (append a b))
                  (let ((r (split-lines b)))
                    (cons (append a (car r)) (cdr r)))))))

(local (defthm split-lines-line
  (implies (and (true-listp a) (no-nl-p a))
           (equal (split-lines a) (list a)))))

(defthm split-lines-of-flat
  (implies (clean-p tx)
           (equal (split-lines (flat tx)) tx))
  :hints (("Goal" :induct (flat tx))))

(defthm flat-of-split-lines
  (implies (true-listp d)
           (equal (flat (split-lines d)) d)))

(defthm flat-injective
  (implies (and (clean-p a) (clean-p b) (equal (flat a) (flat b)))
           (equal a b))
  :hints (("Goal" :use ((:instance split-lines-of-flat (tx a))
                        (:instance split-lines-of-flat (tx b)))
           :in-theory (disable split-lines-of-flat)))
  :rule-classes nil)

(defthm clean-split-lines
  (clean-p (split-lines d)))

;; ---------- Clean text stays clean ----------

(local (in-theory (disable member-is-no-nl)))
(local (defthm not-member-repeat
  (not (member-equal :nl (repeat n nil)))
  :hints (("Goal" :in-theory (enable repeat)))))

(local (defthm not-member-take
  (implies (not (member-equal :nl l))
           (not (member-equal :nl (take n l))))
  :hints (("Goal" :in-theory (enable take)))))
(local (defthm not-member-nthcdr
  (implies (not (member-equal a l))
           (not (member-equal a (nthcdr n l))))
  :hints (("Goal" :in-theory (enable nthcdr)))))
(local (defthm no-nl-rows-nth
  (implies (no-newline-rows-p tx)
           (not (member-equal :nl (nth n tx))))
  :hints (("Goal" :in-theory (enable nth)))))
(local (defthm no-nl-rows-append
  (implies (and (no-newline-rows-p a) (no-newline-rows-p b))
           (no-newline-rows-p (append a b)))))
(local (defthm lines-p-append
  (implies (and (lines-p a) (lines-p b))
           (lines-p (append a b)))))
(local (defthm rows-repeat
  (and (no-newline-rows-p (repeat n nil)) (lines-p (repeat n nil)))
  :hints (("Goal" :in-theory (enable repeat)))))
(local (defthm no-nl-rows-take
  (implies (no-newline-rows-p a) (no-newline-rows-p (take n a)))
  :hints (("Goal" :in-theory (enable take)))))
(local (defthm no-nl-rows-nthcdr
  (implies (no-newline-rows-p a) (no-newline-rows-p (nthcdr n a)))
  :hints (("Goal" :in-theory (enable nthcdr)))))
(local (defthm lines-p-take
  (implies (lines-p a) (lines-p (take n a)))
  :hints (("Goal" :in-theory (enable take)))))
(local (defthm lines-p-nthcdr
  (implies (lines-p a) (lines-p (nthcdr n a)))
  :hints (("Goal" :in-theory (enable nthcdr)))))

(local (defthm rows-cdr
  (implies (and (lines-p a) (no-newline-rows-p a))
           (and (lines-p (cdr a)) (no-newline-rows-p (cdr a))))))
(local (defthm clean-ins-lines
  (implies (and (lines-p ins) (no-newline-rows-p ins)
                (true-listp s)
                (not (member-equal :nl p)) (not (member-equal :nl s)))
           (and (lines-p (ins-lines p ins s))
                (no-newline-rows-p (ins-lines p ins s))))
  :hints (("Goal" :induct (ins-lines p ins s)))))

(local (defthm true-listp-nthcdr-line
  (implies (true-listp l) (true-listp (nthcdr n l)))
  :hints (("Goal" :in-theory (enable nthcdr)))))

(defthm clean-insert-text
  (implies (and (clean-p tx) (clean-p ins) (natp sy) (< sy (len tx)))
           (clean-p (insert-text tx sx sy ins)))
  :hints (("Goal" :in-theory (enable insert-text) :do-not-induct t)))

(defthm clean-delete-text
  (implies (and (clean-p tx) (natp sy) (natp ey) (<= sy ey) (< ey (len tx)))
           (clean-p (delete-text tx sx sy ex ey)))
  :hints (("Goal" :in-theory (enable delete-text) :do-not-induct t)))

;; ---------- Positions after an insert ----------

(defthm insert-start-pos
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx))
                (natp sx) (<= sx (len (nth sy tx))))
           (and (valid-pos-p sx sy (insert-text tx sx sy ins))
                (equal (offset sx sy (insert-text tx sx sy ins))
                       (offset sx sy tx))))
  :hints (("Goal" :do-not-induct t
           :use (len-nth-insert-start
                 (:instance rows-before-insert-unchanged (y sy))))))

(defthm insert-end-pos
  (implies (and (text-p tx) (text-p ins) (natp sy) (< sy (len tx))
                (natp sx) (<= sx (len (nth sy tx))))
           (let ((r (insert-text tx sx sy ins))
                 (ex (insert-end-x sx ins))
                 (ey (insert-end-y sy ins)))
             (and (valid-pos-p ex ey r)
                  (equal (offset ex ey r)
                         (+ (offset sx sy tx) (len (flat ins)))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (insert-end-y insert-end-x) (rows-before-insert-end len-nth-insert-end))
           :use (rows-before-insert-end len-nth-insert-end))))

;; ---------- Positions after a delete ----------

(local (defthm rows-before-take-append
  (implies (and (natp k) (<= k (len l)))
           (equal (rows-before k (append (take k l) b)) (rows-before k l)))
  :hints (("Goal" :induct (cdr-sub k l) :in-theory (enable take)))))

(local (defthm nth-take-append
  (implies (and (natp k) (<= k (len l)))
           (equal (nth k (append (take k l) b)) (car b)))
  :hints (("Goal" :induct (cdr-sub k l) :in-theory (enable take nth)))))

(defthm delete-start-pos
  (implies (and (text-p tx) (natp sy) (< sy (len tx)) (natp ey) (<= sy ey) (< ey (len tx))
                (natp sx) (<= sx (len (nth sy tx))))
           (and (valid-pos-p sx sy (delete-text tx sx sy ex ey))
                (equal (offset sx sy (delete-text tx sx sy ex ey))
                       (offset sx sy tx))))
  :hints (("Goal" :do-not-induct t :in-theory (enable delete-text))))

;; ---------- Flat form of the model's edits ----------

(defthm flat-insert-data
  (implies (and (clean-p tx) (true-listp d) (valid-pos-p sx sy tx))
           (equal (flat (insert-data tx sx sy d))
                  (append (take (offset sx sy tx) (flat tx))
                          d
                          (nthcdr (offset sx sy tx) (flat tx)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable offset-is flat-of-insert clean-split-lines)
           :use ((:instance flat-of-insert (ins (split-lines d)))
                 (:instance clean-split-lines)))))

(defthm flat-delete-text
  (implies (valid-delete-p tx sx sy ex ey)
           (equal (flat (delete-text tx sx sy ex ey))
                  (append (take (offset sx sy tx) (flat tx))
                          (nthcdr (offset ex ey tx) (flat tx)))))
  :hints (("Goal" :in-theory (disable offset-is) :use flat-of-delete)))

(defthm clean-insert-data
  (implies (and (clean-p tx) (natp sy) (< sy (len tx)))
           (clean-p (insert-data tx sx sy d))))

(defthm start-after-insert-data
  (implies (and (clean-p tx) (valid-pos-p sx sy tx))
           (and (valid-pos-p sx sy (insert-data tx sx sy d))
                (equal (offset sx sy (insert-data tx sx sy d))
                       (offset sx sy tx))))
  :hints (("Goal" :do-not-induct t :in-theory (disable offset-is insert-start-pos clean-split-lines valid-pos-p)
           :use ((:instance insert-start-pos (ins (split-lines d)))
                 (:instance clean-split-lines)))
          ("Goal'" :in-theory (e/d (valid-pos-p) (offset-is insert-start-pos clean-split-lines)))))

(local (defthm len-flat-split
  (implies (true-listp d) (equal (len (flat (split-lines d))) (len d)))))

(defthm end-after-insert-data
  (implies (and (clean-p tx) (true-listp d) (valid-pos-p sx sy tx))
           (let ((r (insert-data tx sx sy d))
                 (ex (data-end-x sx d))
                 (ey (data-end-y sy d)))
             (and (valid-pos-p ex ey r)
                  (equal (offset ex ey r) (+ (offset sx sy tx) (len d))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable offset-is insert-end-pos clean-split-lines)
           :use ((:instance insert-end-pos (ins (split-lines d)))
                 (:instance clean-split-lines)))))

(local (defthm consp-split-lines (consp (split-lines d)) :rule-classes :type-prescription))

(local (defthm split-lines-tail
  (implies (cdr (split-lines d)) (consp (cdr (split-lines d))))
  :hints (("Goal" :use ((:instance lines-p-true-listp (tx (split-lines d)))
                        (:instance clean-split-lines))
           :in-theory (disable lines-p-true-listp clean-split-lines)))))

(local (defthm len-gt-1
  (implies (consp (cdr l)) (< 1 (len l)))
  :rule-classes :linear))

(defthm start-le-data-end
  (implies (and (natp sx) (natp sy))
           (pos<= sx sy (data-end-x sx d) (data-end-y sy d)))
  :hints (("Goal" :in-theory (enable pos<= insert-end-x insert-end-y)
           :use ((:instance split-lines-tail)))))

(defthm natp-data-end
  (implies (and (natp sx) (natp sy))
           (and (natp (data-end-x sx d)) (natp (data-end-y sy d))))
  :hints (("Goal" :in-theory (enable insert-end-x insert-end-y))))

;; ---------- Lists ----------

(local (defthm append-take-nthcdr-full
  (implies (and (natp o) (<= o (len f)) (true-listp f))
           (equal (append (take o f) (nthcdr o f)) f))))

(local (defthm append-take-append
  (equal (append (append a b) c) (append a (append b c)))))

(local (defthm take-len-prefix
  (implies (and (natp o) (equal (len a) o))
           (equal (take o (append a b)) (list-fix a)))))

(local (defthm nthcdr-len-prefix
  (implies (and (natp o) (equal (len a) o))
           (equal (nthcdr o (append a b)) b))))

(local (defthm nthcdr-len-prefix2
  (implies (natp k)
           (equal (nthcdr (+ (len a) k) (append a b)) (nthcdr k b)))
  :hints (("Goal" :induct (len a) :in-theory (enable nthcdr)))))

;; ---------- Inverses ----------

(local (defthm offset-le-flat
  (implies (and (text-p tx) (valid-pos-p x y tx))
           (and (natp (offset x y tx))
                (<= (offset x y tx) (len (flat tx)))))
  :hints (("Goal" :use offset-within-flat :in-theory (disable offset-within-flat)))))

(defthm valid-pos-fc
  (implies (valid-pos-p x y tx)
           (and (natp x) (natp y) (< y (len tx)) (<= x (len (nth y tx)))))
  :rule-classes :forward-chaining)

(local (in-theory (disable offset-is valid-pos-p insert-data data-end-x data-end-y)))

(defthm valid-delete-after-insert
  (implies (and (clean-p tx) (true-listp d) (valid-pos-p sx sy tx))
           (valid-delete-p (insert-data tx sx sy d) sx sy
                           (data-end-x sx d) (data-end-y sy d)))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (valid-delete-p valid-pos-p) (start-le-data-end start-after-insert-data end-after-insert-data clean-insert-data))
           :use (start-le-data-end start-after-insert-data end-after-insert-data clean-insert-data))))

(local (defthm offset-monotone
  (implies (and (valid-pos-p sx sy tx) (valid-pos-p ex ey tx) (pos<= sx sy ex ey))
           (<= (offset sx sy tx) (offset ex ey tx)))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (offset-is valid-pos-p pos<=) (offset-order))
           :use ((:instance offset-order (ax sx) (ay sy) (bx ex) (by ey)))))
  :rule-classes (:rewrite :linear)))

(defthm offset-injective
  (implies (and (valid-pos-p ax ay tx) (valid-pos-p bx by tx)
                (equal (offset ax ay tx) (offset bx by tx)))
           (and (equal ax bx) (equal ay by)))
  :hints (("Goal" :do-not-induct t :in-theory (e/d (offset-is valid-pos-p pos<=) (offset-order))
           :use ((:instance offset-order)
                 (:instance offset-order (ax bx) (ay by) (bx ax) (by ay)))))
  :rule-classes nil)

(defthm clean-fc
  (implies (clean-p tx)
           (and (text-p tx) (consp tx) (lines-p tx) (no-newline-rows-p tx)))
  :rule-classes :forward-chaining)

(local (in-theory (disable clean-p)))

(defthm clean-insert-data-valid
  (implies (and (clean-p tx) (valid-pos-p sx sy tx))
           (clean-p (insert-data tx sx sy d))))

(defthm clean-delete-valid
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey))
           (clean-p (delete-text tx sx sy ex ey)))
  :hints (("Goal" :in-theory (enable pos<= valid-pos-p))))

(defthm delete-after-insert
  (implies (and (clean-p tx) (true-listp d) (valid-pos-p sx sy tx))
           (equal (delete-text (insert-data tx sx sy d) sx sy
                               (data-end-x sx d) (data-end-y sy d))
                  tx))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-injective
                            (a (delete-text (insert-data tx sx sy d) sx sy
                                            (data-end-x sx d) (data-end-y sy d)))
                            (b tx))
                 (:instance clean-delete-valid
                            (tx (insert-data tx sx sy d))
                            (ex (data-end-x sx d)) (ey (data-end-y sy d)))
                 (:instance valid-delete-after-insert))
           :in-theory (disable clean-delete-valid valid-delete-p valid-delete-after-insert))))

(defthm region-after-insert
  (implies (and (clean-p tx) (true-listp d) (valid-pos-p sx sy tx))
           (equal (region-text (insert-data tx sx sy d) sx sy
                               (data-end-x sx d) (data-end-y sy d))
                  d))
  :hints (("Goal" :do-not-induct t)))

(defthm start-after-delete
  (implies (valid-delete-p tx sx sy ex ey)
           (and (valid-pos-p sx sy (delete-text tx sx sy ex ey))
                (equal (offset sx sy (delete-text tx sx sy ex ey))
                       (offset sx sy tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (valid-pos-p pos<=) (delete-start-pos))
           :use delete-start-pos)))

(local (defthm split-three
  (implies (and (natp o) (natp e) (<= o e) (<= e (len f)) (true-listp f))
           (equal (append (take o f)
                          (append (take (- e o) (nthcdr o f)) (nthcdr e f)))
                  f))
  :hints (("Goal" :do-not-induct t
           :use ((:instance append-take-nthcdr-full (o (- e o)) (f (nthcdr o f)))
                 (:instance append-take-nthcdr-full))
           :in-theory (disable append-take-nthcdr-full)))))

(defthm true-listp-region
  (implies (lines-p tx) (true-listp (region-text tx sx sy ex ey))))

(defthm len-region
  (implies (and (text-p tx) (valid-pos-p sx sy tx) (valid-pos-p ex ey tx) (pos<= sx sy ex ey))
           (equal (len (region-text tx sx sy ex ey))
                  (- (offset ex ey tx) (offset sx sy tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable offset-monotone offset-le-flat)
           :use (offset-monotone
                 (:instance offset-le-flat (x ex) (y ey))
                 (:instance offset-le-flat (x sx) (y sy))))))

(defthm insert-after-delete
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey))
           (equal (insert-data (delete-text tx sx sy ex ey) sx sy
                               (region-text tx sx sy ex ey))
                  tx))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-injective
                            (a (insert-data (delete-text tx sx sy ex ey) sx sy
                                            (region-text tx sx sy ex ey)))
                            (b tx))
                 (:instance clean-insert-data-valid
                            (tx (delete-text tx sx sy ex ey))
                            (d (region-text tx sx sy ex ey)))
                 (:instance offset-monotone)
                 (:instance offset-le-flat (x ex) (y ey))
                 (:instance offset-le-flat (x sx) (y sy))
                 (:instance split-three (o (offset sx sy tx)) (e (offset ex ey tx))
                            (f (flat tx))))
           :in-theory (disable clean-insert-data-valid offset-monotone offset-le-flat split-three))))

(defthm range-end-is-data-end
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey))
           (let ((d (region-text tx sx sy ex ey)))
             (and (equal (data-end-x sx d) ex)
                  (equal (data-end-y sy d) ey))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance end-after-insert-data
                            (tx (delete-text tx sx sy ex ey))
                            (d (region-text tx sx sy ex ey)))
                 (:instance offset-injective
                            (ax (data-end-x sx (region-text tx sx sy ex ey)))
                            (ay (data-end-y sy (region-text tx sx sy ex ey)))
                            (bx ex) (by ey)))
           :in-theory (disable end-after-insert-data region-text valid-pos-p))))

(defthm insert-at-end-merges
  (implies (and (clean-p tx) (true-listp d1) (true-listp d2) (valid-pos-p sx sy tx))
           (equal (insert-data (insert-data tx sx sy d1)
                               (data-end-x sx d1) (data-end-y sy d1) d2)
                  (insert-data tx sx sy (append d1 d2))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-injective
                            (a (insert-data (insert-data tx sx sy d1)
                                            (data-end-x sx d1) (data-end-y sy d1) d2))
                            (b (insert-data tx sx sy (append d1 d2))))
                 (:instance end-after-insert-data (d d1))
                 (:instance offset-le-flat (x sx) (y sy)))
           :in-theory (disable end-after-insert-data offset-le-flat))))

(defthm insert-at-start-merges
  (implies (and (clean-p tx) (true-listp d1) (true-listp d2) (valid-pos-p sx sy tx))
           (equal (insert-data (insert-data tx sx sy d2) sx sy d1)
                  (insert-data tx sx sy (append d1 d2))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-injective
                            (a (insert-data (insert-data tx sx sy d2) sx sy d1))
                            (b (insert-data tx sx sy (append d1 d2))))
                 (:instance offset-le-flat (x sx) (y sy)))
           :in-theory (disable offset-le-flat))))

;; ---------- The forms the history proofs use ----------

(defthm text-p-split-lines (text-p (split-lines d))
  :hints (("Goal" :use clean-split-lines :in-theory (e/d (clean-p) (clean-split-lines)))))

(defthm typing-merge-text
  (implies (and (clean-p tx) (valid-delete-p tx px py ex ey) (true-listp d2))
           (equal (insert-data tx ex ey d2)
                  (insert-data (delete-text tx px py ex ey) px py
                               (append (region-text tx px py ex ey) d2))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance insert-at-end-merges
                            (tx (delete-text tx px py ex ey)) (sx px) (sy py)
                            (d1 (region-text tx px py ex ey))))
           :in-theory (disable insert-at-end-merges region-text)))
  :rule-classes nil)

(defthm delete-front-merge-text
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey) (true-listp d1))
           (equal (insert-data (delete-text tx sx sy ex ey) sx sy
                               (append d1 (region-text tx sx sy ex ey)))
                  (insert-data tx sx sy d1)))
  :hints (("Goal" :do-not-induct t
           :use ((:instance insert-at-start-merges
                            (tx (delete-text tx sx sy ex ey))
                            (d2 (region-text tx sx sy ex ey))))
           :in-theory (disable insert-at-start-merges region-text))))

(defthm delete-back-merge-text
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey) (true-listp d1))
           (equal (insert-data (delete-text tx sx sy ex ey) sx sy
                               (append (region-text tx sx sy ex ey) d1))
                  (insert-data tx ex ey d1)))
  :hints (("Goal" :do-not-induct t
           :use ((:instance insert-at-end-merges
                            (tx (delete-text tx sx sy ex ey))
                            (d1 (region-text tx sx sy ex ey)) (d2 d1)))
           :in-theory (disable insert-at-end-merges region-text))))

;; Appending rows is an insert of newlines at the end of the text.
(defthm nth-last-row
  (implies (consp tx)
           (equal (nth (+ -1 (len tx)) tx) (car (last tx))))
  :hints (("Goal" :in-theory (enable nth))))

(defthm valid-end-of-text
  (implies (consp tx)
           (valid-pos-p (len (car (last tx))) (+ -1 (len tx)) tx))
  :hints (("Goal" :in-theory (enable valid-pos-p))))

(local (defthm flat-empty-rows
  (implies (not (zp n))
           (equal (flat (empty-rows n)) (nl-list (- n 1))))
  :hints (("Goal" :in-theory (enable flat)))))

(local (defthm rows-empty
  (and (lines-p (empty-rows n)) (no-newline-rows-p (empty-rows n)))))

(local (defthm clean-append-rows
  (implies (clean-p tx) (clean-p (append tx (empty-rows n))))
  :hints (("Goal" :in-theory (enable clean-p) :do-not-induct t))))

(local (defthm offset-end-of-text
  (implies (text-p tx)
           (equal (offset (len (car (last tx))) (+ -1 (len tx)) tx) (len (flat tx))))
  :hints (("Goal" :in-theory (enable offset-is flat rows-before) :induct (flat tx)))))

(local (defthm consp-empty-rows
  (implies (not (zp n)) (consp (empty-rows n)))))

(local (defthm flat-append-rows
  (implies (and (consp tx) (not (zp n)))
           (equal (flat (append tx (empty-rows n)))
                  (append (flat tx) (nl-list n))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-append (a tx) (b (empty-rows n)))
                 (:instance consp-empty-rows))
           :expand ((nl-list n))
           :in-theory (disable flat-append empty-rows consp-empty-rows)))))

(local (defthm nthcdr-len-true
  (implies (true-listp f) (equal (nthcdr (len f) f) nil))))
(local (defthm take-len-true
  (implies (true-listp f) (equal (take (len f) f) f))))

(defthm extend-is-insert
  (implies (and (clean-p tx) (not (zp n)))
           (equal (append tx (empty-rows n))
                  (insert-data tx (len (car (last tx))) (+ -1 (len tx)) (nl-list n))))
  :hints (("Goal" :do-not-induct t
           :use ((:instance flat-injective
                            (a (append tx (empty-rows n)))
                            (b (insert-data tx (len (car (last tx))) (+ -1 (len tx)) (nl-list n))))
                 (:instance valid-end-of-text))
           :in-theory (disable valid-end-of-text)))
  :rule-classes nil)

(local (defthm nl-list-true (true-listp (nl-list n))))
(local (defthm split-nl-list
  (equal (split-lines (nl-list n)) (cons nil (empty-rows n)))
  :hints (("Goal" :in-theory (enable split-lines)))))
(local (defthm last-empty-rows
  (equal (car (last (cons nil (empty-rows n)))) nil)))
(local (defthm last-empty-rows-2
  (not (car (last (empty-rows n))))))
(local (defthm len-empty-rows
  (equal (len (empty-rows n)) (nfix n))))

(defthm extend-data-end
  (implies (not (zp n))
           (and (equal (data-end-x x (nl-list n)) 0)
                (equal (data-end-y y (nl-list n)) (+ y n))))
  :hints (("Goal" :in-theory (enable data-end-x data-end-y insert-end-x insert-end-y)
           :expand ((empty-rows n)))))
