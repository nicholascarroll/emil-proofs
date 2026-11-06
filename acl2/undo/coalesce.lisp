; Claim C: a coalesced run undoes like the same edits made separately.
(in-package "ACL2")

(include-book "redo")

(local (in-theory (disable region-text delete-text insert-data valid-pos-p valid-delete-p
                           clean-p split-lines flat offset data-end-x data-end-y
                           insert-text take nthcdr nth text-p pos<=
                           hist-val edit-refusal)))

;; The text after undoing one group.
(defun g-back (u tx)
  (if (endp u)
      tx
    (let ((t1 (rec-inverse (car u) tx)))
      (if (access undo-rec (car u) :paired)
          (g-back (cdr u) t1)
        t1))))

(defthm g-back-close-run
  (equal (g-back (close-run u) tx) (g-back u tx))
  :hints (("Goal" :in-theory (enable close-run rec-inverse))))

(defthm undo-group-is-g-back
  (equal (access edst (mv-nth 1 (undo-group st)) :text)
         (g-back (access edst st :undo) (access edst st :text)))
  :hints (("Goal" :induct (undo-group st))))

;; ---------- A merged record's inverse is its predecessor's ----------

(defthm inverse-merge-ins
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d) (consp d)
                (consp undo) (undo-matches-p undo tx)
                (not (access undo-rec (car undo) :del))
                (equal (access undo-rec (car undo) :ex) sx)
                (equal (access undo-rec (car undo) :ey) sy))
           (let ((new (ins-rec sx sy d app paired uncapped px py)))
             (equal (rec-inverse (merge-recs (car undo) new :append) (insert-data tx sx sy d))
                    (rec-inverse (car undo) tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (enable rec-inverse ins-rec)
           :expand ((undo-matches-p undo tx))
           :use ((:instance typing-merge-text
                            (px (access undo-rec (car undo) :sx))
                            (py (access undo-rec (car undo) :sy))
                            (ex sx) (ey sy) (d2 d))))))

(defthm inverse-merge-del-front
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp undo) (undo-matches-p undo tx)
                (access undo-rec (car undo) :del)
                (equal (access undo-rec (car undo) :sx) sx)
                (equal (access undo-rec (car undo) :sy) sy))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (equal (rec-inverse (merge-recs (car undo) new :append) (delete-text tx sx sy ex ey))
                    (rec-inverse (car undo) tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (enable rec-inverse del-rec)
           :expand ((undo-matches-p undo tx)))))

(defthm inverse-merge-del-back
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp undo) (undo-matches-p undo tx)
                (access undo-rec (car undo) :del)
                (equal (access undo-rec (car undo) :sx) ex)
                (equal (access undo-rec (car undo) :sy) ey))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (equal (rec-inverse (merge-recs (car undo) new :prepend) (delete-text tx sx sy ex ey))
                    (rec-inverse (car undo) tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (enable rec-inverse del-rec)
           :expand ((undo-matches-p undo tx)))))

(defthm merge-recs-paired
  (equal (access undo-rec (merge-recs prev new shape) :paired)
         (access undo-rec prev :paired)))

;; ---------- Final-newline repair doesn't change what one undo gives ----------

(local (defthm nl-data-end
  (and (equal (data-end-x x '(:nl)) 0)
       (implies (acl2-numberp y) (equal (data-end-y y '(:nl)) (+ y 1))))
  :hints (("Goal" :in-theory (enable data-end-x data-end-y insert-end-x insert-end-y split-lines)))))

(defthm repair-g-back
  (implies (clean-p (access edst st :text))
           (equal (g-back (access edst (repair-final-nl st) :undo)
                          (access edst (repair-final-nl st) :text))
                  (g-back (access edst st :undo) (access edst st :text))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (rec-inverse push-rec) (delete-after-insert))
           :use ((:instance delete-after-insert
                            (tx (access edst st :text))
                            (sx (len (car (last (access edst st :text)))))
                            (sy (+ -1 (len (access edst st :text))))
                            (d '(:nl)))))))

;; ---------- One edit ----------

(defun one-sided-p (tx sx sy ex ey repl)
  (let ((old (region-text tx sx sy ex ey)))
    (or (and (consp old) (endp repl))
        (and (endp old) (consp repl)))))

(defthm run-edit-rec-means
  (implies (run-edit-rec st e)
           (and (not (edit-refusal st (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e) (nth 4 e)))
                (one-sided-p (access edst st :text)
                             (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e) (nth 4 e))))
  :rule-classes nil)

(defthm refusal-means-valid
  (implies (not (edit-refusal st sx sy ex ey repl))
           (valid-delete-p (access edst st :text) sx sy ex ey))
  :hints (("Goal" :in-theory (enable edit-refusal))))

(defthm push-rec-fresh
  (implies (or (not (access undo-rec new :app)) (endp undo)
               (equal (merge-shape (car undo) new) :none))
           (equal (push-rec new undo) (cons new (close-run undo)))))

(defthm push-rec-merged
  (implies (and (access undo-rec new :app) (consp undo)
                (not (equal (merge-shape (car undo) new) :none)))
           (equal (push-rec new undo)
                  (cons (merge-recs (car undo) new (merge-shape (car undo) new)) (cdr undo)))))

(in-theory (disable push-rec merge-shape merge-recs))

(defthm del-rec-parts
  (and (equal (access undo-rec (del-rec tx sx sy ex ey app paired u px py) :app) app)
       (equal (access undo-rec (del-rec tx sx sy ex ey app paired u px py) :paired) paired))
  :hints (("Goal" :in-theory (enable del-rec))))

(defthm ins-rec-parts
  (and (equal (access undo-rec (ins-rec sx sy d app paired u px py) :app) app)
       (equal (access undo-rec (ins-rec sx sy d app paired u px py) :paired) paired))
  :hints (("Goal" :in-theory (enable ins-rec))))

(defthm inverse-del-rec
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey))
           (equal (rec-inverse (del-rec tx sx sy ex ey app paired u px py)
                               (delete-text tx sx sy ex ey))
                  tx))
  :hints (("Goal" :in-theory (enable del-rec rec-inverse))))

(defthm inverse-ins-rec
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d))
           (equal (rec-inverse (ins-rec sx sy d app paired u px py)
                               (insert-data tx sx sy d))
                  tx))
  :hints (("Goal" :in-theory (enable ins-rec rec-inverse))))

;; A one-sided edit that makes a fresh record.
(defthm core-fresh-del
  (let* ((tx (access edst st :text)) (u0 (access edst st :undo))
         (co (and coalesce t))
         (rec (del-rec tx sx sy ex ey co nil (and co burst)
                       (access edst st :cx) (access edst st :cy))))
    (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                  (consp (region-text tx sx sy ex ey))
                  (or (not co) (endp u0) (equal (merge-shape (car u0) rec) :none)))
             (equal (g-back (access edst (edit-core st sx sy ex ey nil nil coalesce burst) :undo)
                            (access edst (edit-core st sx sy ex ey nil nil coalesce burst) :text))
                    tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable core-t1 core-u1))))

(defthm core-fresh-ins
  (let* ((tx (access edst st :text)) (u0 (access edst st :undo))
         (co (and coalesce t))
         (rec (ins-rec sx sy repl co nil (and co burst)
                       (access edst st :cx) (access edst st :cy))))
    (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                  (not (consp (region-text tx sx sy ex ey)))
                  (consp repl) (true-listp repl)
                  (or (not co) (endp u0) (equal (merge-shape (car u0) rec) :none)))
             (equal (g-back (access edst (edit-core st sx sy ex ey repl nil coalesce burst) :undo)
                            (access edst (edit-core st sx sy ex ey repl nil coalesce burst) :text))
                    tx)))
  :hints (("Goal" :do-not-induct t :in-theory (enable core-t1 core-u1))))

;; A one-sided edit that folds into the head.
(defthm merge-means-unpaired
  (implies (not (equal (merge-shape prev new) :none))
           (not (access undo-rec prev :paired)))
  :hints (("Goal" :in-theory (enable merge-shape))))

(defthm core-merged-del
  (let* ((tx (access edst st :text)) (u0 (access edst st :undo))
         (rec (del-rec tx sx sy ex ey t nil burst (access edst st :cx) (access edst st :cy))))
    (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                  (consp (region-text tx sx sy ex ey))
                  (undo-matches-p u0 tx) (consp u0)
                  (not (equal (merge-shape (car u0) rec) :none)))
             (equal (g-back (access edst (edit-core st sx sy ex ey nil nil t burst) :undo)
                            (access edst (edit-core st sx sy ex ey nil nil t burst) :text))
                    (rec-inverse (car u0) tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (core-t1 core-u1) (inverse-merge-del-front inverse-merge-del-back merge-means-unpaired))
           :use ((:instance merge-means-unpaired
                            (prev (car (access edst st :undo)))
                            (new (del-rec (access edst st :text) sx sy ex ey t nil burst
                                          (access edst st :cx) (access edst st :cy))))
                 (:instance merge-shape-del
                            (prev (car (access edst st :undo)))
                            (tx (access edst st :text))
                            (app t) (paired nil) (uncapped burst)
                            (px (access edst st :cx)) (py (access edst st :cy)))
                 (:instance inverse-merge-del-front
                            (tx (access edst st :text)) (undo (access edst st :undo))
                            (app t) (paired nil) (uncapped burst)
                            (px (access edst st :cx)) (py (access edst st :cy)))
                 (:instance inverse-merge-del-back
                            (tx (access edst st :text)) (undo (access edst st :undo))
                            (app t) (paired nil) (uncapped burst)
                            (px (access edst st :cx)) (py (access edst st :cy)))))))

(defthm core-merged-ins
  (let* ((tx (access edst st :text)) (u0 (access edst st :undo))
         (rec (ins-rec sx sy repl t nil burst (access edst st :cx) (access edst st :cy))))
    (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                  (not (consp (region-text tx sx sy ex ey)))
                  (consp repl) (true-listp repl)
                  (undo-matches-p u0 tx) (consp u0)
                  (not (equal (merge-shape (car u0) rec) :none)))
             (equal (g-back (access edst (edit-core st sx sy ex ey repl nil t burst) :undo)
                            (access edst (edit-core st sx sy ex ey repl nil t burst) :text))
                    (rec-inverse (car u0) tx))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (core-t1 core-u1) (inverse-merge-ins merge-means-unpaired))
           :use ((:instance merge-means-unpaired
                            (prev (car (access edst st :undo)))
                            (new (ins-rec sx sy repl t nil burst
                                          (access edst st :cx) (access edst st :cy))))
                 (:instance merge-shape-ins
                            (prev (car (access edst st :undo))) (d repl)
                            (app t) (paired nil) (uncapped burst)
                            (px (access edst st :cx)) (py (access edst st :cy)))
                 (:instance inverse-merge-ins
                            (tx (access edst st :text)) (undo (access edst st :undo)) (d repl)
                            (app t) (paired nil) (uncapped burst)
                            (px (access edst st :cx)) (py (access edst st :cy)))))))

;; ---------- In terms of RUN-EDIT ----------

(defthm run-edit-rec-shape
  (implies (run-edit-rec st e)
           (let ((tx (access edst st :text))
                 (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e))
                 (repl (nth 4 e)) (burst (nth 5 e))
                 (px (access edst st :cx)) (py (access edst st :cy)))
             (if (consp (region-text tx sx sy ex ey))
                 (and (endp repl)
                      (equal (run-edit-rec st e) (del-rec tx sx sy ex ey t nil burst px py)))
               (and (consp repl)
                    (equal (run-edit-rec st e) (ins-rec sx sy repl t nil burst px py))))))
  :hints (("Goal" :in-theory (enable del-rec ins-rec)))
  :rule-classes nil)

(defthm edit-repl-nil-norm
  (implies (not (consp repl))
           (equal (edit-core st sx sy ex ey repl chain coalesce burst)
                  (edit-core st sx sy ex ey nil chain coalesce burst)))
  :hints (("Goal" :in-theory (enable edit-core)))
  :rule-classes nil)

;; After an accepted edit, the text one undo gives.
(defthm run-edit-g-back
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e)))
           (equal (g-back (access edst (run-edit st e coalesce) :undo)
                          (access edst (run-edit st e coalesce) :text))
                  (g-back (access edst (edit-core st (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e)
                                                  (nth 4 e) nil coalesce (nth 5 e)) :undo)
                          (access edst (edit-core st (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e)
                                                  (nth 4 e) nil coalesce (nth 5 e)) :text))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (edit-is-core) (repair-final-nl edit-core-ok run-edit-rec hist-ok))
           :use ((:instance run-edit-rec-means)
                 (:instance edit-core-ok
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e))
                            (repl (nth 4 e)) (chain nil) (burst (nth 5 e)))))
          ("Goal'" :in-theory (e/d (edit-is-core hist-ok) (repair-final-nl edit-core-ok run-edit-rec)))))

(defthm hist-ok-parts
  (implies (hist-ok st)
           (and (clean-p (access edst st :text))
                (undo-matches-p (access edst st :undo) (access edst st :text))))
  :rule-classes :forward-chaining)

(defthm run-edit-fresh
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e))
                (or (not coalesce) (endp (access edst st :undo))
                    (equal (merge-shape (car (access edst st :undo)) (run-edit-rec st e)) :none)))
           (equal (g-back (access edst (run-edit st e coalesce) :undo)
                          (access edst (run-edit st e coalesce) :text))
                  (access edst st :text)))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable run-edit run-edit-rec hist-ok core-fresh-del core-fresh-ins refusal-means-valid)
           :use ((:instance run-edit-rec-means)
                 (:instance run-edit-rec-shape)
                 (:instance refusal-means-valid
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e)) (repl (nth 4 e)))
                 (:instance core-fresh-del
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e)) (burst (nth 5 e)))
                 (:instance core-fresh-ins
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e))
                            (repl (nth 4 e)) (burst (nth 5 e)))))))

(defthm run-edit-merged
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e))
                (consp (access edst st :undo))
                (not (equal (merge-shape (car (access edst st :undo)) (run-edit-rec st e)) :none)))
           (equal (g-back (access edst (run-edit st e t) :undo)
                          (access edst (run-edit st e t) :text))
                  (g-back (access edst st :undo) (access edst st :text))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable run-edit run-edit-rec hist-ok core-merged-del core-merged-ins merge-means-unpaired refusal-means-valid)
           :use ((:instance run-edit-rec-means)
                 (:instance run-edit-rec-shape)
                 (:instance refusal-means-valid
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e)) (repl (nth 4 e)))
                 (:instance merge-means-unpaired (prev (car (access edst st :undo))) (new (run-edit-rec st e)))
                 (:instance core-merged-del
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e)) (burst (nth 5 e)))
                 (:instance core-merged-ins
                            (sx (nth 0 e)) (sy (nth 1 e)) (ex (nth 2 e)) (ey (nth 3 e))
                            (repl (nth 4 e)) (burst (nth 5 e)))))))

(defthm run-edit-ok
  (implies (and (hist-ok st) (true-listp (nth 4 e)))
           (hist-ok (run-edit st e c)))
  :hints (("Goal" :in-theory (disable hist-ok edit))))

(defthm chain-g-back
  (implies (and (hist-ok ct) (edits-ok-p es) (run-merges-p ct es))
           (equal (g-back (access edst (run-all ct es t) :undo)
                          (access edst (run-all ct es t) :text))
                  (g-back (access edst ct :undo) (access edst ct :text))))
  :hints (("Goal" :induct (run-merges-p ct es)
           :in-theory (disable hist-ok run-edit run-edit-rec g-back))))

;; ---------- One undo of the coalesced run ----------

(defthm coalesced-text
  (implies (and (hist-ok st) (edits-ok-p es) (run-ok-p st es))
           (equal (g-back (access edst (run-all st es t) :undo)
                          (access edst (run-all st es t) :text))
                  (access edst st :text)))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok run-edit run-edit-rec g-back chain-g-back run-edit-fresh)
           :use ((:instance run-edit-fresh (e (car es)) (coalesce t))
                 (:instance chain-g-back (ct (run-edit st (car es) t)) (es (cdr es)))))))

(defthm undo-times-0
  (equal (mv-nth 1 (undo-times st 0)) st)
  :hints (("Goal" :expand ((undo-times st 0)))))

(defthm g-back-endp
  (implies (not (consp u)) (equal (g-back u tx) tx)))

(defthm undo-times-1
  (equal (access edst (mv-nth 1 (undo-times st 1)) :text)
         (g-back (access edst st :undo) (access edst st :text)))
  :hints (("Goal" :do-not-induct t
           :expand ((undo-times st 1))
           :in-theory (disable undo-group g-back))))

(defthm do-undo-1-is-g-back
  (implies (not (access edst st :read-only))
           (equal (access edst (mv-nth 1 (do-undo st 1)) :text)
                  (g-back (access edst st :undo) (access edst st :text))))
  :hints (("Goal" :do-not-induct t :in-theory (disable undo-times g-back))))

;; ---------- The separate edits ----------

;; Text, wants-nl and read-only are all that an edit's text depends on.
(defun view (st)
  (list (access edst st :text) (access edst st :wants-nl) (access edst st :read-only)))

(defthm view-same-means
  (implies (equal (view a) (view b))
           (and (equal (access edst a :text) (access edst b :text))
                (equal (access edst a :wants-nl) (access edst b :wants-nl))
                (equal (access edst a :read-only) (access edst b :read-only))))
  :rule-classes nil)

(defthm repair-text-depends
  (implies (equal (view a) (view b))
           (equal (access edst (repair-final-nl a) :text)
                  (access edst (repair-final-nl b) :text)))
  :hints (("Goal" :do-not-induct t)))

(defthm edit-text-only-depends-on-view
  (implies (equal (view a) (view b))
           (equal (view (run-edit a e c1)) (view (run-edit b e c2))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (edit-is-core edit-refusal) (repair-final-nl))
           :use ((:instance repair-text-depends
                            (a (edit-core a (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e) (nth 4 e) nil c1 (nth 5 e)))
                            (b (edit-core b (nth 0 e) (nth 1 e) (nth 2 e) (nth 3 e) (nth 4 e) nil c2 (nth 5 e)))))))
  :rule-classes nil)

(defthm run-edit-rec-view
  (implies (equal (view a) (view b))
           (iff (run-edit-rec a e) (run-edit-rec b e)))
  :hints (("Goal" :do-not-induct t :in-theory (enable edit-refusal)))
  :rule-classes nil)

(defun run-all2 (a b es c1 c2)
  (declare (xargs :measure (len es)))
  (if (endp es)
      (list a b)
    (run-all2 (run-edit a (car es) c1) (run-edit b (car es) c2) (cdr es) c1 c2)))

(defthm run-all-view
  (implies (equal (view a) (view b))
           (equal (view (run-all a es c1)) (view (run-all b es c2))))
  :hints (("Goal" :induct (run-all2 a b es c1 c2)
           :in-theory (disable view run-edit))
          ("Subgoal *1/2" :use ((:instance edit-text-only-depends-on-view (e (car es))))))
  :rule-classes nil)

;; Every edit of the coalesced run is also accepted and one-sided in the separate run.
(defun sep-good (st es)
  (declare (xargs :measure (len es)))
  (if (endp es)
      t
    (and (run-edit-rec st (car es))
         (sep-good (run-edit st (car es) nil) (cdr es)))))

(defun merges2 (a b es)
  (declare (xargs :measure (len es)))
  (if (endp es)
      (list a b)
    (merges2 (run-edit a (car es) t) (run-edit b (car es) nil) (cdr es))))

(defthm merges-means-sep-good
  (implies (and (equal (view a) (view b)) (run-merges-p a es))
           (sep-good b es))
  :hints (("Goal" :induct (merges2 a b es)
           :in-theory (disable view run-edit run-edit-rec merge-shape))
          ("Subgoal *1/2" :use ((:instance edit-text-only-depends-on-view (e (car es)) (c1 t) (c2 nil))
                                (:instance run-edit-rec-view (e (car es)))))))

(defthm run-ok-means-sep-good
  (implies (run-ok-p st es) (sep-good st es))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable view run-edit run-edit-rec merges-means-sep-good)
           :use ((:instance merges-means-sep-good
                            (a (run-edit st (car es) t))
                            (b (run-edit st (car es) nil))
                            (es (cdr es)))
                 (:instance edit-text-only-depends-on-view (a st) (b st) (e (car es)) (c1 t) (c2 nil))))))

;; ---------- What undoing a group does to the undo list ----------

(defun g-rest (u)
  (cond ((endp u) u)
        ((access undo-rec (car u) :paired) (g-rest (cdr u)))
        (t (cdr u))))

(defun g-ex (u)
  (cond ((endp u) t)
        ((access undo-rec (car u) :paired) (g-ex (cdr u)))
        (t nil)))

(defthm z-undo-group-parts
  (and (equal (nth 0 (mv-nth 1 (z-undo-group z))) (g-back (nth 1 z) (nth 0 z)))
       (equal (nth 1 (mv-nth 1 (z-undo-group z))) (g-rest (nth 1 z)))
       (iff (mv-nth 0 (z-undo-group z)) (g-ex (nth 1 z))))
  :hints (("Goal" :induct (z-undo-group z)
           :in-theory (enable z-undo-step nth))))

(defthm g-back-strip
  (equal (g-back (strip-recs u) tx) (g-back u tx))
  :hints (("Goal" :induct (g-back u tx))))

(defthm g-rest-strip-cons-unpaired
  (implies (not (access undo-rec r :paired))
           (and (equal (g-rest (cons (strip-rec r) u)) u)
                (not (g-ex (cons (strip-rec r) u))))))

(defthm g-rest-strip-cons-paired
  (implies (access undo-rec r :paired)
           (and (equal (g-rest (cons (strip-rec r) u)) (g-rest u))
                (equal (g-ex (cons (strip-rec r) u)) (g-ex u)))))

(in-theory (disable g-rest g-ex))

(defthm repair-g-rest
  (and (equal (g-rest (strip-recs (access edst (repair-final-nl st) :undo)))
              (g-rest (strip-recs (access edst st :undo))))
       (equal (g-ex (strip-recs (access edst (repair-final-nl st) :undo)))
              (g-ex (strip-recs (access edst st :undo)))))
  :hints (("Goal" :do-not-induct t)))

;; One accepted, one-sided edit without coalescing is one group.
(defthm separate-edit-group
  (implies (and (run-edit-rec st e) (true-listp (nth 4 e)))
           (let ((u (access edst (run-edit st e nil) :undo)))
             (and (equal (g-rest (strip-recs u)) (strip-recs (access edst st :undo)))
                  (not (g-ex (strip-recs u))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (edit-is-core core-u1) (repair-final-nl run-edit-rec))
           :use ((:instance run-edit-rec-means)
                 (:instance run-edit-rec-shape)))))

;; ---------- Undoing the separate edits, one group each ----------

(defthm z-undo-times-snoc
  (implies (natp k)
           (equal (z-undo-times z (+ 1 k))
                  (mv-let (r z1)
                    (z-undo-times z k)
                    (cond ((not (equal r :done)) (mv r z1))
                          ((endp (nth 1 z1)) (mv :exhausted z1))
                          (t (mv-let (ex z2)
                               (z-undo-group z1)
                               (if ex (mv :exhausted z2) (mv :done z2))))))))
  :hints (("Goal" :induct (z-undo-times z k) :in-theory (disable z-undo-group z-undo-group-parts)
           :do-not '(generalize fertilize eliminate-destructors)
           :expand ((z-undo-times z 1) (z-undo-times (mv-nth 1 (z-undo-group z)) 0)
                    (z-undo-times z (+ 1 k))))))

(defthm run-edit-group-text
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e)))
           (let ((s1 (run-edit st e nil)))
             (and (equal (g-back (strip-recs (access edst s1 :undo)) (access edst s1 :text))
                         (access edst st :text))
                  (consp (access edst s1 :undo)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok run-edit run-edit-rec separate-edit-group g-ex)
           :use ((:instance run-edit-fresh (coalesce nil))
                 (:instance separate-edit-group)))
          ("Subgoal 1" :in-theory (e/d (g-ex) (hist-ok run-edit run-edit-rec separate-edit-group)))))

(defun sep-zip (st r)
  (list (access edst st :text) (strip-recs (access edst st :undo)) r))

(defthm z-undo-times-0
  (equal (z-undo-times z 0) (list :done z))
  :hints (("Goal" :expand ((z-undo-times z 0)))))

(defthm sep-zip-parts
  (and (equal (nth 0 (sep-zip st r)) (access edst st :text))
       (equal (nth 1 (sep-zip st r)) (strip-recs (access edst st :undo))))
  :hints (("Goal" :in-theory (enable nth))))

;; One more group, given where the earlier undos left off.
(defthm one-more-group-g
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e))
                (equal t1 (access edst (run-edit st e nil) :text))
                (equal u1 (strip-recs (access edst (run-edit st e nil) :undo))))
           (and (consp u1)
                (not (g-ex u1))
                (equal (g-back u1 t1) (access edst st :text))
                (equal (g-rest u1) (strip-recs (access edst st :undo)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok run-edit run-edit-rec separate-edit-group run-edit-group-text g-ex g-rest z-undo-group)
           :use ((:instance separate-edit-group)
                 (:instance run-edit-group-text))))
  :rule-classes nil)

(defthm one-more-group
  (implies (and (hist-ok st) (run-edit-rec st e) (true-listp (nth 4 e))
                (equal (nth 0 z1) (access edst (run-edit st e nil) :text))
                (equal (nth 1 z1) (strip-recs (access edst (run-edit st e nil) :undo))))
           (and (consp (nth 1 z1))
                (not (mv-nth 0 (z-undo-group z1)))
                (equal (nth 0 (mv-nth 1 (z-undo-group z1))) (access edst st :text))
                (equal (nth 1 (mv-nth 1 (z-undo-group z1))) (strip-recs (access edst st :undo)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok run-edit run-edit-rec g-ex g-rest z-undo-group g-back-strip)
           :use ((:instance one-more-group-g (t1 (nth 0 z1)) (u1 (nth 1 z1))))))
  :rule-classes nil)

(defthm sep-undo
  (implies (and (hist-ok st) (edits-ok-p es) (sep-good st es))
           (let* ((z (sep-zip (run-all st es nil) r))
                  (res (z-undo-times z (len es))))
             (and (equal (mv-nth 0 res) :done)
                  (equal (nth 0 (mv-nth 1 res)) (access edst st :text))
                  (equal (nth 1 (mv-nth 1 res)) (strip-recs (access edst st :undo))))))
  :hints (("Goal" :induct (sep-good st es)
           :in-theory (disable hist-ok run-edit run-edit-rec z-undo-group z-undo-times g-ex g-rest sep-zip
                               z-undo-group-parts))
          ("Subgoal *1/2" :use ((:instance one-more-group
                                  (e (car es))
                                  (z1 (mv-nth 1 (z-undo-times (sep-zip (run-all (run-edit st (car es) nil) (cdr es) nil) r)
                                                              (len (cdr es))))))))))

;; ---------- Claim C ----------

(defthm run-all-flags
  (equal (access edst (run-all st es c) :read-only) (access edst st :read-only))
  :hints (("Goal" :induct (run-all st es c) :in-theory (disable edit))))

(defthm run-all-ok
  (implies (and (hist-ok st) (edits-ok-p es)) (hist-ok (run-all st es c)))
  :hints (("Goal" :induct (run-all st es c) :in-theory (disable hist-ok run-edit))))

(defthm len-not-0-when-consp
  (implies (consp es) (not (equal (len es) 0))))

(defthm separate-text
  (implies (and (hist-ok st) (edits-ok-p es) (sep-good st es) (consp es)
                (not (access edst st :read-only)))
           (equal (access edst (mv-nth 1 (do-undo (run-all st es nil) (len es))) :text)
                  (access edst st :text)))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (sep-zip) (hist-ok do-undo z-undo-times run-edit zipper-do-undo sep-undo run-all
                                      zipper-parts))
           :use ((:instance zipper-do-undo (st (run-all st es nil)) (c (len es)))
                 (:instance sep-undo (r (strip-recs (access edst (run-all st es nil) :redo))))
                 (:instance zipper (st (run-all st es nil)))
                 (:instance text-of-zipper (st (mv-nth 1 (do-undo (run-all st es nil) (len es)))))))))

(defthm run-ok-consp
  (implies (run-ok-p st es) (consp es))
  :rule-classes :forward-chaining)

(defthm c-at-state
  (implies (and (hist-ok st) (edits-ok-p es) (run-ok-p st es)
                (not (access edst st :read-only)))
           (and (equal (access edst (run-all st es t) :text)
                       (access edst (run-all st es nil) :text))
                (equal (access edst (mv-nth 1 (do-undo (run-all st es t) 1)) :text)
                       (access edst (mv-nth 1 (do-undo (run-all st es nil) (len es))) :text))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok do-undo run-all run-ok-p run-edit g-back view)
           :use ((:instance run-all-view (a st) (b st) (c1 t) (c2 nil))
                 (:instance view-same-means (a (run-all st es t)) (b (run-all st es nil)))))))

;; CLAIM C: undoing a coalesced run once gives the same text as undoing the same
;; edits, made separately, once per edit.
(defthm claim-c-holds
  (claim-c tx wants-nl ops es)
  :hints (("Goal" :do-not-induct t
           :in-theory (disable do-undo run-ops initial-st hist-ok run-all run-ok-p c-at-state
                               initial-ok run-ops-ok hist-val)
           :use (initial-ok
                 (:instance run-ops-ok (st (initial-st tx wants-nl)))
                 (:instance c-at-state (st (run-ops (initial-st tx wants-nl) ops)))))))
