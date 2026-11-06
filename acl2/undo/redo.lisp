; Claim B: redo after undo restores the text.
;
; Undo and redo don't depend on the cursor or on records' APPEND flags.  So this works on
; a zipper: the text and the two lists with APPEND flags cleared.
(in-package "ACL2")

(include-book "history")

(local (in-theory (disable region-text delete-text insert-data valid-pos-p valid-delete-p
                           clean-p split-lines flat offset data-end-x data-end-y
                           insert-text take nthcdr nth text-p pos<=
                           hist-val)))

;; ---------- The zipper ----------

(defun strip-rec (r) (change undo-rec r :app nil))

(defun strip-recs (l)
  (if (endp l) nil (cons (strip-rec (car l)) (strip-recs (cdr l)))))

(defun zipper (st)
  (list (access edst st :text)
        (strip-recs (access edst st :undo))
        (strip-recs (access edst st :redo))))

(defun z-undo-step (z)
  (let ((tx (nth 0 z)) (u (nth 1 z)) (r (nth 2 z)))
    (list (rec-inverse (car u) tx) (cdr u) (cons (car u) r))))

(defun z-redo-step (z)
  (let ((tx (nth 0 z)) (u (nth 1 z)) (r (nth 2 z)))
    (list (rec-apply (car r) tx) (cons (car r) u) (cdr r))))

(defun z-undo-group (z)
  (declare (xargs :measure (len (nth 1 z))))
  (if (endp (nth 1 z))
      (mv t z)
    (let ((paired (access undo-rec (car (nth 1 z)) :paired))
          (z1 (z-undo-step z)))
      (if paired (z-undo-group z1) (mv nil z1)))))

(defun z-redo-rest (z)
  (declare (xargs :measure (len (nth 2 z))))
  (if (and (consp (nth 2 z)) (access undo-rec (car (nth 2 z)) :paired))
      (z-redo-rest (z-redo-step z))
    z))

(defun z-redo-group (z) (z-redo-rest (z-redo-step z)))

(defun z-undo-times (z n)
  (declare (xargs :measure (nfix n)))
  (cond ((zp n) (mv :done z))
        ((endp (nth 1 z)) (mv :exhausted z))
        (t (mv-let (ex z1)
             (z-undo-group z)
             (if ex (mv :exhausted z1) (z-undo-times z1 (- n 1)))))))

(defun z-redo-times (z n)
  (declare (xargs :measure (nfix n)))
  (cond ((zp n) (mv :done z))
        ((endp (nth 2 z)) (mv :exhausted z))
        (t (z-redo-times (z-redo-group z) (- n 1)))))

;; ---------- The model projects onto it ----------

(defthm strip-close-run
  (equal (strip-recs (close-run u)) (strip-recs u))
  :hints (("Goal" :in-theory (enable close-run))))

(defthm consp-strip (equal (consp (strip-recs l)) (consp l)))

(defthm rec-inverse-strip
  (equal (rec-inverse (strip-rec r) tx) (rec-inverse r tx))
  :hints (("Goal" :in-theory (enable rec-inverse))))

(defthm rec-apply-strip
  (equal (rec-apply (strip-rec r) tx) (rec-apply r tx))
  :hints (("Goal" :in-theory (enable rec-apply))))

(defthm car-strip-recs
  (implies (consp l) (equal (car (strip-recs l)) (strip-rec (car l)))))

(in-theory (disable strip-rec))

(defthm paired-strip
  (equal (access undo-rec (strip-rec r) :paired) (access undo-rec r :paired))
  :hints (("Goal" :in-theory (enable strip-rec))))

(defthm zip-undo-step
  (implies (consp (access edst st :undo))
           (equal (zipper (undo-step st)) (z-undo-step (zipper st)))))

(defthm zip-redo-step
  (implies (consp (access edst st :redo))
           (equal (zipper (redo-step st)) (z-redo-step (zipper st)))))

(defthm zipper-parts
  (and (equal (nth 0 (zipper st)) (access edst st :text))
       (equal (nth 1 (zipper st)) (strip-recs (access edst st :undo)))
       (equal (nth 2 (zipper st)) (strip-recs (access edst st :redo))))
  :hints (("Goal" :in-theory (enable nth))))

(in-theory (disable zipper))

(defthm zipper-undo-group
  (and (equal (mv-nth 0 (undo-group st)) (mv-nth 0 (z-undo-group (zipper st))))
       (equal (zipper (mv-nth 1 (undo-group st))) (mv-nth 1 (z-undo-group (zipper st)))))
  :hints (("Goal" :induct (undo-group st) :in-theory (disable z-undo-step)
           :expand ((z-undo-group (zipper st))))))

(defthm zipper-redo-rest
  (equal (zipper (redo-rest st px py)) (z-redo-rest (zipper st)))
  :hints (("Goal" :induct (redo-rest st px py) :in-theory (e/d (zipper) (z-redo-step adjust-spec))
           :expand ((z-redo-rest (list (access edst st :text)
                                       (strip-recs (access edst st :undo))
                                       (strip-recs (access edst st :redo))))))))

(defthm zipper-redo-group
  (implies (consp (access edst st :redo))
           (equal (zipper (redo-group st)) (z-redo-group (zipper st))))
  :hints (("Goal" :in-theory (disable redo-rest z-redo-rest z-redo-step zipper-redo-rest)
           :use ((:instance zipper-redo-rest
                            (st (redo-step st))
                            (px (access undo-rec (car (access edst st :redo)) :sx))
                            (py (access undo-rec (car (access edst st :redo)) :sy)))))))

(defthm zipper-undo-times
  (and (equal (mv-nth 0 (undo-times st n)) (mv-nth 0 (z-undo-times (zipper st) n)))
       (equal (zipper (mv-nth 1 (undo-times st n))) (mv-nth 1 (z-undo-times (zipper st) n))))
  :hints (("Goal" :induct (undo-times st n)
           :in-theory (disable undo-group z-undo-group)
           :expand ((z-undo-times (zipper st) n)))))

(defthm zipper-redo-times
  (and (equal (mv-nth 0 (redo-times st n)) (mv-nth 0 (z-redo-times (zipper st) n)))
       (equal (zipper (mv-nth 1 (redo-times st n))) (mv-nth 1 (z-redo-times (zipper st) n))))
  :hints (("Goal" :induct (redo-times st n)
           :in-theory (disable redo-group z-redo-group)
           :expand ((z-redo-times (zipper st) n)))))

(defthm zipper-close
  (equal (zipper (change edst st :undo (close-run (access edst st :undo))))
         (zipper st))
  :hints (("Goal" :in-theory (enable zipper))))

;; ---------- On the zipper: undoing then redoing a group is the identity ----------

(defun z-ok (z)
  (and (clean-p (nth 0 z))
       (undo-matches-p (nth 1 z) (nth 0 z))
       (redo-matches-p (nth 2 z) (nth 0 z))))

;; Only a chain with nothing before it can leave a paired record at the head of redo.
(defun z-j (z)
  (implies (and (consp (nth 2 z)) (access undo-rec (car (nth 2 z)) :paired))
           (endp (nth 1 z))))

(defthm undo-matches-strip
  (equal (undo-matches-p (strip-recs u) tx) (undo-matches-p u tx))
  :hints (("Goal" :in-theory (enable strip-rec))))

(defthm redo-matches-strip
  (equal (redo-matches-p (strip-recs u) tx) (redo-matches-p u tx))
  :hints (("Goal" :in-theory (enable strip-rec))))

(defthm z-ok-of-hist-ok
  (implies (hist-ok st) (z-ok (zipper st))))

(defthm z-parts
  (and (equal (nth 0 (list a b c)) a) (equal (nth 1 (list a b c)) b) (equal (nth 2 (list a b c)) c))
  :hints (("Goal" :in-theory (enable nth))))

(defthm apply-after-inverse
  (implies (and (clean-p tx) (consp u) (undo-matches-p u tx))
           (equal (rec-apply (car u) (rec-inverse (car u) tx)) tx))
  :hints (("Goal" :do-not-induct t :in-theory (enable rec-apply rec-inverse)
           :expand ((undo-matches-p u tx)))))

(defthm z-undo-step-ok
  (implies (and (z-ok z) (consp (nth 1 z)))
           (z-ok (z-undo-step z)))
  :hints (("Goal" :do-not-induct t)))

(defun z-shape (z) (equal z (list (nth 0 z) (nth 1 z) (nth 2 z))))

(defthm z-shape-zipper (z-shape (zipper st))
  :hints (("Goal" :in-theory (enable zipper nth))))

(defthm z-shape-steps
  (and (z-shape (z-undo-step z)) (z-shape (z-redo-step z)))
  :hints (("Goal" :in-theory (enable nth))))

(defthm z-redo-after-undo-step
  (implies (and (z-ok z) (z-shape z) (consp (nth 1 z)))
           (equal (z-redo-step (z-undo-step z)) z))
  :hints (("Goal" :do-not-induct t)))

(in-theory (disable z-shape z-ok))

(defthm z-undo-step-parts
  (and (equal (nth 1 (z-undo-step z)) (cdr (nth 1 z)))
       (equal (nth 2 (z-undo-step z)) (cons (car (nth 1 z)) (nth 2 z)))))

(in-theory (disable z-undo-step z-redo-step))

;; Undoing a group and redoing a group continues as redo would have from the start.
(defthm z-redo-group-undo-group
  (implies (and (z-ok z) (z-shape z) (not (mv-nth 0 (z-undo-group z))))
           (equal (z-redo-group (mv-nth 1 (z-undo-group z))) (z-redo-rest z)))
  :hints (("Goal" :induct (z-undo-group z))
          ("Subgoal *1/2" :expand ((z-redo-rest (z-undo-step z))))))

;; ---------- Facts about a group's result ----------

(defthm z-undo-group-keeps
  (implies (and (z-ok z) (z-shape z))
           (and (z-ok (mv-nth 1 (z-undo-group z)))
                (z-shape (mv-nth 1 (z-undo-group z)))))
  :hints (("Goal" :induct (z-undo-group z))))

(defthm z-undo-group-head
  (implies (not (mv-nth 0 (z-undo-group z)))
           (let ((r (nth 2 (mv-nth 1 (z-undo-group z)))))
             (and (consp r) (not (access undo-rec (car r) :paired)))))
  :hints (("Goal" :induct (z-undo-group z))))

(defthm z-undo-group-exhausted
  (implies (mv-nth 0 (z-undo-group z))
           (not (consp (nth 1 (mv-nth 1 (z-undo-group z))))))
  :hints (("Goal" :induct (z-undo-group z))))

(defthm z-j-after-undo-group
  (implies (z-j z) (z-j (mv-nth 1 (z-undo-group z))))
  :hints (("Goal" :do-not-induct t :in-theory (disable z-undo-group z-undo-group-head z-undo-group-exhausted)
           :cases ((mv-nth 0 (z-undo-group z)))
           :use (z-undo-group-head z-undo-group-exhausted))))

(defthm z-redo-rest-identity
  (implies (and (z-j z) (consp (nth 1 z)))
           (equal (z-redo-rest z) z))
  :hints (("Goal" :expand ((z-redo-rest z)))))

(defthm z-redo-times-snoc
  (implies (natp k)
           (equal (z-redo-times z (+ 1 k))
                  (mv-let (r z1)
                    (z-redo-times z k)
                    (cond ((not (equal r :done)) (mv r z1))
                          ((endp (nth 2 z1)) (mv :exhausted z1))
                          (t (mv :done (z-redo-group z1)))))))
  :hints (("Goal" :induct (z-redo-times z k) :in-theory (disable z-redo-group)
           :expand ((z-redo-times z 1) (z-redo-times (z-redo-group z) 0) (z-redo-times z (+ 1 k))))))

;; ---------- Redoing N groups after undoing N groups ----------

(defthm z-undo-redo-times
  (implies (and (z-ok z) (z-shape z) (z-j z)
                (equal (mv-nth 0 (z-undo-times z n)) :done))
           (and (equal (mv-nth 0 (z-redo-times (mv-nth 1 (z-undo-times z n)) n)) :done)
                (equal (mv-nth 1 (z-redo-times (mv-nth 1 (z-undo-times z n)) n)) z)))
  :hints (("Goal" :induct (z-undo-times z n) :in-theory (disable z-undo-group z-redo-group))
          ("Subgoal *1/4" :in-theory (disable z-undo-group z-redo-group z-redo-times-snoc)
                          :use ((:instance z-redo-times-snoc
                                           (z (mv-nth 1 (z-undo-times (mv-nth 1 (z-undo-group z)) (+ -1 n))))
                                           (k (+ -1 n)))))))

;; ---------- J holds in every reached state ----------

(defthm z-j-after-undo-times
  (implies (z-j z) (z-j (mv-nth 1 (z-undo-times z n))))
  :hints (("Goal" :induct (z-undo-times z n) :in-theory (disable z-j z-undo-group))))

(defthm z-j-redo-rest
  (z-j (z-redo-rest z))
  :hints (("Goal" :induct (z-redo-rest z))))

(defthm z-j-after-redo-times
  (implies (z-j z) (z-j (mv-nth 1 (z-redo-times z n))))
  :hints (("Goal" :induct (z-redo-times z n) :in-theory (disable z-j z-redo-rest))))

(defthm zipper-do-undo
  (and (equal (mv-nth 0 (do-undo st c))
              (if (access edst st :read-only) :refused
                (mv-nth 0 (z-undo-times (zipper st) (if (zp c) 1 c)))))
       (equal (zipper (mv-nth 1 (do-undo st c)))
              (if (access edst st :read-only) (zipper st)
                (mv-nth 1 (z-undo-times (zipper st) (if (zp c) 1 c))))))
  :hints (("Goal" :do-not-induct t :in-theory (disable undo-times z-undo-times zipper-undo-times)
           :use ((:instance zipper-undo-times
                            (st (change edst st :undo (close-run (access edst st :undo))))
                            (n (if (zp c) 1 c)))))))

(defthm zipper-do-redo
  (and (equal (mv-nth 0 (do-redo st c))
              (if (access edst st :read-only) :refused
                (mv-nth 0 (z-redo-times (zipper st) (if (zp c) 1 c)))))
       (equal (zipper (mv-nth 1 (do-redo st c)))
              (if (access edst st :read-only) (zipper st)
                (mv-nth 1 (z-redo-times (zipper st) (if (zp c) 1 c))))))
  :hints (("Goal" :do-not-induct t :in-theory (disable redo-times z-redo-times zipper-redo-times)
           :use ((:instance zipper-redo-times
                            (st (change edst st :undo (close-run (access edst st :undo))))
                            (n (if (zp c) 1 c)))))))

(defun st-j (st) (z-j (zipper st)))

(defthm st-j-nil-redo
  (implies (not (consp (access edst st :redo))) (st-j st)))

(defthm edit-redo
  (implies (not (edit-refusal st sx sy ex ey repl))
           (equal (access edst (edit st sx sy ex ey repl chain coalesce burst) :redo) nil))
  :hints (("Goal" :in-theory (e/d (edit-is-core) (repair-final-nl)))))

(defthm edit-refused
  (implies (edit-refusal st sx sy ex ey repl)
           (equal (edit st sx sy ex ey repl chain coalesce burst) st))
  :hints (("Goal" :in-theory (enable edit-is-core))))

(in-theory (disable edit-refusal))

(defthm st-j-edit
  (implies (st-j st) (st-j (edit st sx sy ex ey repl chain coalesce burst)))
  :hints (("Goal" :do-not-induct t :cases ((edit-refusal st sx sy ex ey repl))
           :in-theory (disable st-j edit))))

(defthm st-j-extend
  (implies (st-j st) (st-j (extend-rows st from n)))
  :hints (("Goal" :do-not-induct t :in-theory (disable st-j push-rec))
          ("Goal'" :in-theory (disable push-rec))))

(defthm st-j-do-undo
  (implies (st-j st) (st-j (mv-nth 1 (do-undo st c))))
  :hints (("Goal" :do-not-induct t :in-theory (disable do-undo z-undo-times z-j))))

(defthm st-j-do-redo
  (implies (st-j st) (st-j (mv-nth 1 (do-redo st c))))
  :hints (("Goal" :do-not-induct t :in-theory (disable do-redo z-redo-times z-j))))

(defthm st-j-cursor
  (equal (st-j (change edst st :cx x :cy y)) (st-j st))
  :hints (("Goal" :in-theory (enable zipper))))

(defthm st-j-close
  (equal (st-j (change edst st :undo (close-run (access edst st :undo)))) (st-j st)))

(in-theory (disable st-j))

(defthm run-op-j
  (implies (st-j st) (st-j (run-op st op)))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable do-undo do-redo edit extend-rows))))

(defthm run-ops-j
  (implies (st-j st) (st-j (run-ops st ops)))
  :hints (("Goal" :induct (run-ops st ops) :in-theory (disable run-op))))

(defthm initial-j (st-j (initial-st tx w)))

;; ---------- Claim B ----------

(defthm text-of-zipper
  (equal (access edst st :text) (nth 0 (zipper st)))
  :rule-classes nil)

(defthm do-undo-read-only
  (equal (access edst (mv-nth 1 (do-undo st c)) :read-only) (access edst st :read-only))
  :hints (("Goal" :in-theory (disable undo-times))))

(defthm undo-redo-state
  (implies (and (hist-ok st) (st-j st) (posp n)
                (equal (mv-nth 0 (do-undo st n)) :done))
           (and (equal (mv-nth 0 (do-redo (mv-nth 1 (do-undo st n)) n)) :done)
                (equal (access edst (mv-nth 1 (do-redo (mv-nth 1 (do-undo st n)) n)) :text)
                       (access edst st :text))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (st-j) (do-undo do-redo z-undo-times z-redo-times hist-ok z-j
                                   z-undo-redo-times zipper-parts))
           :use ((:instance z-undo-redo-times (z (zipper st)))
                 (:instance z-ok-of-hist-ok)
                 (:instance text-of-zipper)
                 (:instance text-of-zipper (st (mv-nth 1 (do-redo (mv-nth 1 (do-undo st n)) n))))))
          ("Subgoal 2'" :in-theory (e/d (st-j) (do-undo do-redo z-undo-times z-redo-times hist-ok z-j z-undo-redo-times zipper-parts)))))

;; CLAIM B: if N groups could be undone, redoing N groups restores the text.
(defthm claim-b-holds
  (claim-b tx wants-nl ops n)
  :hints (("Goal" :do-not-induct t
           :in-theory (disable do-undo do-redo run-ops initial-st hist-ok undo-redo-state
                               initial-ok run-ops-ok hist-val)
           :use (initial-ok
                 (:instance run-ops-ok (st (initial-st tx wants-nl)))
                 (:instance undo-redo-state (st (run-ops (initial-st tx wants-nl) ops)))))))
