; Claim R and the rewinding fact behind claim A.
; A record's replay and what it needs of the text.
(in-package "ACL2")

(include-book "text")

(local (in-theory (disable region-text delete-text insert-data valid-pos-p valid-delete-p
                           clean-p split-lines flat offset data-end-x data-end-y
                           insert-text take nthcdr nth)))

;; The text before a record, from the text after it.
(defthm clean-text-p
  (implies (clean-p tx) (text-p tx)))

(defthm valid-delete-fc
  (implies (valid-delete-p tx sx sy ex ey)
           (and (valid-pos-p sx sy tx) (valid-pos-p ex ey tx) (pos<= sx sy ex ey)))
  :hints (("Goal" :in-theory (enable valid-delete-p)))
  :rule-classes :forward-chaining)

(local (in-theory (disable text-p pos<=)))

(defun rec-inverse (r tx)
  (if (access undo-rec r :del)
      (insert-data tx (access undo-rec r :sx) (access undo-rec r :sy)
                   (access undo-rec r :data))
    (delete-text tx (access undo-rec r :sx) (access undo-rec r :sy)
                 (access undo-rec r :ex) (access undo-rec r :ey))))

;; Undoing every record, newest first.
(defun rewind (undo tx)
  (if (endp undo)
      tx
    (rewind (cdr undo) (rec-inverse (car undo) tx))))

;; ---------- close-run changes nothing that matters ----------

(defthm undo-matches-close-run
  (equal (undo-matches-p (close-run undo) tx) (undo-matches-p undo tx)))

(defthm rewind-close-run
  (equal (rewind (close-run undo) tx) (rewind undo tx)))

(defthm consp-close-run
  (equal (consp (close-run undo)) (consp undo)))

;; ---------- A new insert record ----------

(defun ins-rec (sx sy d app paired uncapped px py)
  (make-undo-rec sx sy (data-end-x sx d) (data-end-y sy d) nil d app paired uncapped px py))

(defthm ok-ins-fresh
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d) (consp d))
           (rec-range-ok-p (ins-rec sx sy d app paired uncapped px py))))

(defthm push-ins-no-merge
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d) (consp d)
                (undo-matches-p undo tx))
           (and (undo-matches-p (cons (ins-rec sx sy d app paired uncapped px py)
                                      (close-run undo))
                                (insert-data tx sx sy d))
                (equal (rewind (cons (ins-rec sx sy d app paired uncapped px py)
                                     (close-run undo))
                               (insert-data tx sx sy d))
                       (rewind undo tx))))
  :hints (("Goal" :do-not-induct t)))

(defthm push-ins-merge
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d) (consp d)
                (consp undo) (undo-matches-p undo tx)
                (not (access undo-rec (car undo) :del))
                (equal (access undo-rec (car undo) :ex) sx)
                (equal (access undo-rec (car undo) :ey) sy))
           (let ((new (ins-rec sx sy d app paired uncapped px py)))
             (and (undo-matches-p (cons (merge-recs (car undo) new :append) (cdr undo))
                                  (insert-data tx sx sy d))
                  (equal (rewind (cons (merge-recs (car undo) new :append) (cdr undo))
                                 (insert-data tx sx sy d))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           :expand ((undo-matches-p undo tx))
           :use ((:instance typing-merge-text
                            (px (access undo-rec (car undo) :sx))
                            (py (access undo-rec (car undo) :sy))
                            (ex sx) (ey sy) (d2 d))))))

;; The result of pushing an insert record, whichever way push-rec goes.
(defthm merge-shape-ins
  (let ((shape (merge-shape prev (ins-rec sx sy d app paired uncapped px py))))
    (and (or (equal shape :none) (equal shape :append))
         (implies (not (equal shape :none))
                  (and (not (access undo-rec prev :del))
                       (equal (access undo-rec prev :ex) sx)
                       (equal (access undo-rec prev :ey) sy)))))
  :rule-classes nil)

(defthm push-ins
  (implies (and (clean-p tx) (valid-pos-p sx sy tx) (true-listp d) (consp d)
                (undo-matches-p undo tx))
           (let ((new (ins-rec sx sy d app paired uncapped px py)))
             (and (undo-matches-p (push-rec new undo) (insert-data tx sx sy d))
                  (equal (rewind (push-rec new undo) (insert-data tx sx sy d))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (push-rec)
                           (merge-shape merge-recs rewind undo-matches-p
                            push-ins-merge push-ins-no-merge rec-range-ok-p))
           :use (push-ins-merge push-ins-no-merge
                 (:instance merge-shape-ins (prev (car undo)))))))

;; ---------- A new delete record ----------

(defun del-rec (tx sx sy ex ey app paired uncapped px py)
  (make-undo-rec sx sy ex ey t (region-text tx sx sy ex ey) app paired uncapped px py))

(defthm push-del-no-merge
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp (region-text tx sx sy ex ey))
                (undo-matches-p undo tx))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (and (undo-matches-p (cons new (close-run undo)) (delete-text tx sx sy ex ey))
                  (equal (rewind (cons new (close-run undo)) (delete-text tx sx sy ex ey))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           )))

(defthm push-del-merge-front
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp (region-text tx sx sy ex ey))
                (consp undo) (undo-matches-p undo tx)
                (access undo-rec (car undo) :del)
                (equal (access undo-rec (car undo) :sx) sx)
                (equal (access undo-rec (car undo) :sy) sy))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (and (undo-matches-p (cons (merge-recs (car undo) new :append) (cdr undo))
                                  (delete-text tx sx sy ex ey))
                  (equal (rewind (cons (merge-recs (car undo) new :append) (cdr undo))
                                 (delete-text tx sx sy ex ey))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           :expand ((undo-matches-p undo tx)))))

(defthm push-del-merge-back
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp (region-text tx sx sy ex ey))
                (consp undo) (undo-matches-p undo tx)
                (access undo-rec (car undo) :del)
                (equal (access undo-rec (car undo) :sx) ex)
                (equal (access undo-rec (car undo) :sy) ey))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (and (undo-matches-p (cons (merge-recs (car undo) new :prepend) (cdr undo))
                                  (delete-text tx sx sy ex ey))
                  (equal (rewind (cons (merge-recs (car undo) new :prepend) (cdr undo))
                                 (delete-text tx sx sy ex ey))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           :expand ((undo-matches-p undo tx)))))

(defthm merge-shape-del
  (let ((shape (merge-shape prev (del-rec tx sx sy ex ey app paired uncapped px py))))
    (and (or (equal shape :none) (equal shape :append) (equal shape :prepend))
         (implies (equal shape :append)
                  (and (access undo-rec prev :del)
                       (equal (access undo-rec prev :sx) sx)
                       (equal (access undo-rec prev :sy) sy)))
         (implies (equal shape :prepend)
                  (and (access undo-rec prev :del)
                       (equal (access undo-rec prev :sx) ex)
                       (equal (access undo-rec prev :sy) ey)))))
  :rule-classes nil)

(defthm push-del
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (consp (region-text tx sx sy ex ey))
                (undo-matches-p undo tx))
           (let ((new (del-rec tx sx sy ex ey app paired uncapped px py)))
             (and (undo-matches-p (push-rec new undo) (delete-text tx sx sy ex ey))
                  (equal (rewind (push-rec new undo) (delete-text tx sx sy ex ey))
                         (rewind undo tx)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (push-rec)
                           (merge-shape merge-recs rewind undo-matches-p
                            push-del-merge-front push-del-merge-back
                            push-del-no-merge rec-range-ok-p))
           :use (push-del-merge-front push-del-merge-back push-del-no-merge
                 (:instance merge-shape-del (prev (car undo)))))))

;; ---------- One undo step and one redo step ----------

(defun hist-ok (st)
  (and (clean-p (access edst st :text))
       (undo-matches-p (access edst st :undo) (access edst st :text))
       (redo-matches-p (access edst st :redo) (access edst st :text))))

(defun hist-val (st)
  (rewind (access edst st :undo) (access edst st :text)))

(defthm insert-after-delete-d
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey)
                (equal (region-text tx sx sy ex ey) d))
           (equal (insert-data (delete-text tx sx sy ex ey) sx sy d) tx)))

(defthm undo-step-text-clean
  (implies (and (clean-p tx) (consp undo) (undo-matches-p undo tx))
           (clean-p (rec-inverse (car undo) tx)))
  :hints (("Goal" :do-not-induct t :expand ((undo-matches-p undo tx)))))

(defthm undo-step-makes-redo-match
  (implies (and (clean-p tx) (consp undo) (undo-matches-p undo tx) (redo-matches-p redo tx))
           (redo-matches-p (cons (car undo) redo) (rec-inverse (car undo) tx)))
  :hints (("Goal" :do-not-induct t :expand ((undo-matches-p undo tx)))))

(defthm undo-matches-after-step
  (implies (and (consp undo) (undo-matches-p undo tx))
           (undo-matches-p (cdr undo) (rec-inverse (car undo) tx)))
  :hints (("Goal" :do-not-induct t :expand ((undo-matches-p undo tx)))))

(defun rec-apply (r tx)
  (if (access undo-rec r :del)
      (delete-text tx (access undo-rec r :sx) (access undo-rec r :sy)
                   (access undo-rec r :ex) (access undo-rec r :ey))
    (insert-data tx (access undo-rec r :sx) (access undo-rec r :sy)
                 (access undo-rec r :data))))

(defthm redo-step-text-clean
  (implies (and (clean-p tx) (consp redo) (redo-matches-p redo tx))
           (clean-p (rec-apply (car redo) tx)))
  :hints (("Goal" :do-not-induct t :expand ((redo-matches-p redo tx)))))

(defthm redo-step-makes-undo-match
  (implies (and (clean-p tx) (consp redo) (redo-matches-p redo tx) (undo-matches-p undo tx))
           (and (undo-matches-p (cons (car redo) undo) (rec-apply (car redo) tx))
                (equal (rewind (cons (car redo) undo) (rec-apply (car redo) tx))
                       (rewind undo tx))))
  :hints (("Goal" :do-not-induct t :expand ((redo-matches-p redo tx)))))

(defthm redo-matches-after-step
  (implies (and (consp redo) (redo-matches-p redo tx))
           (redo-matches-p (cdr redo) (rec-apply (car redo) tx)))
  :hints (("Goal" :do-not-induct t :expand ((redo-matches-p redo tx)))))

;; The steps' text, in those terms.
(defthm undo-step-text
  (equal (access edst (undo-step st) :text)
         (rec-inverse (car (access edst st :undo)) (access edst st :text))))

(defthm undo-step-lists
  (and (equal (access edst (undo-step st) :undo)
              (close-run (cdr (access edst st :undo))))
       (equal (access edst (undo-step st) :redo)
              (cons (car (access edst st :undo)) (access edst st :redo)))))

(defthm redo-step-text
  (equal (access edst (redo-step st) :text)
         (rec-apply (car (access edst st :redo)) (access edst st :text))))

(defthm redo-step-lists
  (and (equal (access edst (redo-step st) :undo)
              (close-run (cons (car (access edst st :redo)) (access edst st :undo))))
       (equal (access edst (redo-step st) :redo)
              (cdr (access edst st :redo)))))

(in-theory (disable undo-step redo-step rec-inverse rec-apply close-run))

;; ---------- Edits ----------

;; EDIT's body up to the final-newline repair.
(defun edit-core (st sx sy ex ey repl chain coalesce burst)
  (let* ((tx (access edst st :text))
         (old (region-text tx sx sy ex ey))
         (px (access edst st :cx))
         (py (access edst st :cy))
         (is-replace (and (consp old) (consp repl)))
         (co (and coalesce (not is-replace) (not chain)))
         (uncapped (and co burst))
         (u0 (access edst st :undo))
         (u1 (if (consp old)
                 (push-rec (del-rec tx sx sy ex ey co (and chain t) uncapped px py) u0)
               u0))
         (t1 (if (consp old) (delete-text tx sx sy ex ey) tx))
         (u2 (if (consp repl)
                 (push-rec (ins-rec sx sy repl co (or is-replace (and chain t)) uncapped px py) u1)
               u1))
         (t2 (if (consp repl) (insert-data t1 sx sy repl) t1)))
    (change edst st :text t2 :undo u2 :redo nil)))

(defthm edit-is-core
  (equal (edit st sx sy ex ey repl chain coalesce burst)
         (if (edit-refusal st sx sy ex ey repl)
             st
           (repair-final-nl (edit-core st sx sy ex ey repl chain coalesce burst)))))

(defun core-t1 (tx sx sy ex ey)
  (if (consp (region-text tx sx sy ex ey)) (delete-text tx sx sy ex ey) tx))

(defun core-u1 (tx u0 sx sy ex ey app paired uncapped px py)
  (if (consp (region-text tx sx sy ex ey))
      (push-rec (del-rec tx sx sy ex ey app paired uncapped px py) u0)
    u0))

(defthm core-1
  (implies (and (clean-p tx) (valid-delete-p tx sx sy ex ey) (undo-matches-p u0 tx))
           (let ((t1 (core-t1 tx sx sy ex ey))
                 (u1 (core-u1 tx u0 sx sy ex ey app paired uncapped px py)))
             (and (clean-p t1)
                  (valid-pos-p sx sy t1)
                  (undo-matches-p u1 t1)
                  (equal (rewind u1 t1) (rewind u0 tx)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable del-rec push-rec rewind undo-matches-p))))

(defthm core-2
  (implies (and (clean-p t1) (valid-pos-p sx sy t1) (undo-matches-p u1 t1) (true-listp repl))
           (let ((t2 (if (consp repl) (insert-data t1 sx sy repl) t1))
                 (u2 (if (consp repl)
                         (push-rec (ins-rec sx sy repl app paired uncapped px py) u1)
                       u1)))
             (and (clean-p t2)
                  (undo-matches-p u2 t2)
                  (equal (rewind u2 t2) (rewind u1 t1)))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable ins-rec push-rec rewind undo-matches-p))))

(defthm edit-core-text
  (equal (access edst (edit-core st sx sy ex ey repl chain coalesce burst) :text)
         (let ((t1 (core-t1 (access edst st :text) sx sy ex ey)))
           (if (consp repl) (insert-data t1 sx sy repl) t1))))

(defthm edit-core-undo
  (equal (access edst (edit-core st sx sy ex ey repl chain coalesce burst) :undo)
         (let* ((tx (access edst st :text))
                (old (region-text tx sx sy ex ey))
                (is-replace (and (consp old) (consp repl)))
                (co (and coalesce (not is-replace) (not chain)))
                (uncapped (and co burst))
                (px (access edst st :cx)) (py (access edst st :cy))
                (u1 (core-u1 tx (access edst st :undo) sx sy ex ey co (and chain t) uncapped px py)))
           (if (consp repl)
               (push-rec (ins-rec sx sy repl co (or is-replace (and chain t)) uncapped px py) u1)
             u1))))

(defthm edit-core-redo
  (equal (access edst (edit-core st sx sy ex ey repl chain coalesce burst) :redo) nil))

(defthm edit-core-other
  (and (equal (access edst (edit-core st sx sy ex ey repl chain coalesce burst) :wants-nl)
              (access edst st :wants-nl))
       (equal (access edst (edit-core st sx sy ex ey repl chain coalesce burst) :read-only)
              (access edst st :read-only))))

(in-theory (disable edit-core core-t1 core-u1 del-rec ins-rec))

(defthm redo-matches-nil (implies (not (consp r)) (redo-matches-p r tx)))

(defthm edit-core-ok
  (implies (and (hist-ok st) (true-listp repl)
                (valid-delete-p (access edst st :text) sx sy ex ey))
           (and (hist-ok (edit-core st sx sy ex ey repl chain coalesce burst))
                (equal (hist-val (edit-core st sx sy ex ey repl chain coalesce burst))
                       (hist-val st))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable core-1 core-2 push-rec rewind undo-matches-p redo-matches-p)
           :use ((:instance core-1 (tx (access edst st :text)) (u0 (access edst st :undo))
                  (app (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain)))
                  (paired (and chain t))
                  (uncapped (and (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain)) burst))
                  (px (access edst st :cx)) (py (access edst st :cy)))
                 (:instance core-2
                  (t1 (core-t1 (access edst st :text) sx sy ex ey))
                  (u1 (core-u1 (access edst st :text) (access edst st :undo) sx sy ex ey
                               (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain))
                               (and chain t)
                               (and (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain)) burst)
                               (access edst st :cx) (access edst st :cy)))
                  (app (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain)))
                  (paired (or (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl)) (and chain t)))
                  (uncapped (and (and coalesce (not (and (consp (region-text (access edst st :text) sx sy ex ey)) (consp repl))) (not chain)) burst))
                  (px (access edst st :cx)) (py (access edst st :cy)))))))

;; ---------- Final-newline repair and extension ----------

(local (defthm nl-data-end
  (and (equal (data-end-x x '(:nl)) 0)
       (implies (acl2-numberp y) (equal (data-end-y y '(:nl)) (+ y 1))))
  :hints (("Goal" :in-theory (enable data-end-x data-end-y insert-end-x insert-end-y split-lines)))))

(defthm repair-ok
  (implies (and (hist-ok st) (endp (access edst st :redo)))
           (and (hist-ok (repair-final-nl st))
                (equal (hist-val (repair-final-nl st)) (hist-val st))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (ins-rec) (push-ins push-rec rewind undo-matches-p redo-matches-p))
           :use ((:instance push-ins
                            (tx (access edst st :text))
                            (undo (access edst st :undo))
                            (sx (len (car (last (access edst st :text)))))
                            (sy (+ -1 (len (access edst st :text))))
                            (d '(:nl)) (app nil) (paired t) (uncapped nil) (px 0) (py -1))))))

(defthm repair-other
  (and (equal (access edst (repair-final-nl st) :redo) (access edst st :redo))
       (equal (access edst (repair-final-nl st) :wants-nl) (access edst st :wants-nl))
       (equal (access edst (repair-final-nl st) :read-only) (access edst st :read-only))))

(defthm edit-ok
  (implies (and (hist-ok st) (true-listp repl))
           (and (hist-ok (edit st sx sy ex ey repl chain coalesce burst))
                (equal (hist-val (edit st sx sy ex ey repl chain coalesce burst))
                       (hist-val st))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok hist-val repair-final-nl edit)
           :cases ((edit-refusal st sx sy ex ey repl)))
          ("Subgoal 2" :in-theory (e/d (edit-refusal) (hist-ok hist-val repair-final-nl edit)))))

(in-theory (disable edit-is-core edit))

(defthm nl-list-facts
  (and (true-listp (nl-list n))
       (implies (not (zp n)) (consp (nl-list n)))))

(defthm extend-ok
  (implies (hist-ok st)
           (and (hist-ok (extend-rows st from n))
                (equal (hist-val (extend-rows st from n)) (hist-val st))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (ins-rec) (push-ins push-rec rewind undo-matches-p redo-matches-p))
           :use ((:instance push-ins
                            (tx (access edst st :text))
                            (undo (access edst st :undo))
                            (sx (len (car (last (access edst st :text)))))
                            (sy (+ -1 (len (access edst st :text))))
                            (d (nl-list n)) (app nil) (paired nil) (uncapped nil) (px 0) (py -1))
                 (:instance extend-is-insert (tx (access edst st :text)))))))

;; ---------- Groups, counts and commands ----------

(defthm undo-step-ok
  (implies (and (hist-ok st) (consp (access edst st :undo)))
           (and (hist-ok (undo-step st))
                (equal (hist-val (undo-step st)) (hist-val st))))
  :hints (("Goal" :do-not-induct t :expand ((rewind (access edst st :undo) (access edst st :text))))))

(defthm redo-step-ok
  (implies (and (hist-ok st) (consp (access edst st :redo)))
           (and (hist-ok (redo-step st))
                (equal (hist-val (redo-step st)) (hist-val st))))
  :hints (("Goal" :do-not-induct t)))

(defthm undo-group-ok
  (implies (hist-ok st)
           (and (hist-ok (mv-nth 1 (undo-group st)))
                (equal (hist-val (mv-nth 1 (undo-group st))) (hist-val st))))
  :hints (("Goal" :induct (undo-group st) :in-theory (disable hist-ok hist-val))))

(defthm redo-rest-ok
  (implies (hist-ok st)
           (and (hist-ok (redo-rest st px py))
                (equal (hist-val (redo-rest st px py)) (hist-val st))))
  :hints (("Goal" :induct (redo-rest st px py) :in-theory (disable adjust-spec))))

(defthm redo-group-ok
  (implies (and (hist-ok st) (consp (access edst st :redo)))
           (and (hist-ok (redo-group st))
                (equal (hist-val (redo-group st)) (hist-val st))))
  :hints (("Goal" :do-not-induct t :in-theory (disable hist-ok hist-val redo-rest))))

(defthm undo-times-ok
  (implies (hist-ok st)
           (and (hist-ok (mv-nth 1 (undo-times st n)))
                (equal (hist-val (mv-nth 1 (undo-times st n))) (hist-val st))))
  :hints (("Goal" :induct (undo-times st n) :in-theory (disable hist-ok hist-val undo-group))))

(defthm redo-times-ok
  (implies (hist-ok st)
           (and (hist-ok (mv-nth 1 (redo-times st n)))
                (equal (hist-val (mv-nth 1 (redo-times st n))) (hist-val st))))
  :hints (("Goal" :induct (redo-times st n) :in-theory (disable hist-ok hist-val redo-group))))

(defthm close-ok
  (implies (hist-ok st)
           (and (hist-ok (change edst st :undo (close-run (access edst st :undo))))
                (equal (hist-val (change edst st :undo (close-run (access edst st :undo))))
                       (hist-val st)))))

(defthm do-undo-ok
  (implies (hist-ok st)
           (and (hist-ok (mv-nth 1 (do-undo st c)))
                (equal (hist-val (mv-nth 1 (do-undo st c))) (hist-val st))))
  :hints (("Goal" :do-not-induct t :in-theory (disable hist-ok hist-val undo-times))))

(defthm do-redo-ok
  (implies (hist-ok st)
           (and (hist-ok (mv-nth 1 (do-redo st c)))
                (equal (hist-val (mv-nth 1 (do-redo st c))) (hist-val st))))
  :hints (("Goal" :do-not-induct t :in-theory (disable hist-ok hist-val redo-times))))

;; ---------- Any sequence ----------

(defthm cursor-ok
  (and (equal (hist-ok (change edst st :cx x :cy y)) (hist-ok st))
       (equal (hist-val (change edst st :cx x :cy y)) (hist-val st))))

(defthm run-op-ok
  (implies (and (hist-ok st) (op-ok-p op))
           (and (hist-ok (run-op st op))
                (equal (hist-val (run-op st op)) (hist-val st))))
  :hints (("Goal" :do-not-induct t
           :in-theory (disable hist-ok hist-val edit extend-rows do-undo do-redo))))

(defthm run-ops-ok
  (implies (and (hist-ok st) (ops-ok-p ops))
           (and (hist-ok (run-ops st ops))
                (equal (hist-val (run-ops st ops)) (hist-val st))))
  :hints (("Goal" :induct (run-ops st ops) :in-theory (disable hist-ok hist-val run-op))))

(defthm initial-ok
  (implies (initial-ok-p tx)
           (and (hist-ok (initial-st tx wants-nl))
                (equal (hist-val (initial-st tx wants-nl)) tx)))
  :hints (("Goal" :in-theory (enable clean-p))))

;; CLAIM R: after any sequence, every record matches the text it will replay on.
(defthm claim-r-holds
  (claim-r tx wants-nl ops)
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (clean-p) (hist-ok hist-val initial-st run-ops initial-ok run-ops-ok))
           :use (initial-ok (:instance run-ops-ok (st (initial-st tx wants-nl))))
           :expand ((hist-ok (run-ops (initial-st tx wants-nl) ops))))))

;; ---------- Read-only and wants-nl don't change in these sequences ----------

(defthm step-flags
  (and (equal (access edst (undo-step st) :read-only) (access edst st :read-only))
       (equal (access edst (undo-step st) :wants-nl) (access edst st :wants-nl))
       (equal (access edst (redo-step st) :read-only) (access edst st :read-only))
       (equal (access edst (redo-step st) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :in-theory (enable undo-step redo-step))))

(defthm undo-group-flags
  (and (equal (access edst (mv-nth 1 (undo-group st)) :read-only) (access edst st :read-only))
       (equal (access edst (mv-nth 1 (undo-group st)) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :induct (undo-group st))))

(defthm redo-rest-flags
  (and (equal (access edst (redo-rest st px py) :read-only) (access edst st :read-only))
       (equal (access edst (redo-rest st px py) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :induct (redo-rest st px py) :in-theory (disable adjust-spec))))

(defthm redo-group-flags
  (and (equal (access edst (redo-group st) :read-only) (access edst st :read-only))
       (equal (access edst (redo-group st) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :in-theory (disable redo-rest))))

(defthm undo-times-flags
  (and (equal (access edst (mv-nth 1 (undo-times st n)) :read-only) (access edst st :read-only))
       (equal (access edst (mv-nth 1 (undo-times st n)) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :induct (undo-times st n) :in-theory (disable undo-group))))

(defthm redo-times-flags
  (and (equal (access edst (mv-nth 1 (redo-times st n)) :read-only) (access edst st :read-only))
       (equal (access edst (mv-nth 1 (redo-times st n)) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :induct (redo-times st n) :in-theory (disable redo-group))))

(defthm edit-flags
  (and (equal (access edst (edit st sx sy ex ey repl chain coalesce burst) :read-only)
              (access edst st :read-only))
       (equal (access edst (edit st sx sy ex ey repl chain coalesce burst) :wants-nl)
              (access edst st :wants-nl)))
  :hints (("Goal" :in-theory (e/d (edit-is-core) (repair-final-nl)))))

(defthm run-op-flags
  (and (equal (access edst (run-op st op) :read-only) (access edst st :read-only))
       (equal (access edst (run-op st op) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :in-theory (disable edit undo-times redo-times))))

(defthm run-ops-flags
  (and (equal (access edst (run-ops st ops) :read-only) (access edst st :read-only))
       (equal (access edst (run-ops st ops) :wants-nl) (access edst st :wants-nl)))
  :hints (("Goal" :induct (run-ops st ops) :in-theory (disable run-op))))

;; ---------- Claim A ----------

(defthm len-close-run
  (equal (len (close-run u)) (len u))
  :hints (("Goal" :in-theory (enable close-run))))

(defthm undo-group-shrinks
  (implies (consp (access edst st :undo))
           (< (len (access edst (mv-nth 1 (undo-group st)) :undo))
              (len (access edst st :undo))))
  :hints (("Goal" :induct (undo-group st)))
  :rule-classes :linear)

(defthm undo-group-exhausted
  (implies (mv-nth 0 (undo-group st))
           (not (consp (access edst (mv-nth 1 (undo-group st)) :undo))))
  :hints (("Goal" :induct (undo-group st))))

(defthm undo-times-empties
  (implies (and (natp n) (< (len (access edst st :undo)) n))
           (not (consp (access edst (mv-nth 1 (undo-times st n)) :undo))))
  :hints (("Goal" :induct (undo-times st n) :in-theory (disable undo-group))
          ("Subgoal *1/4" :use undo-group-shrinks)))

(defthm hist-val-empty
  (implies (not (consp (access edst st :undo)))
           (equal (hist-val st) (access edst st :text))))

;; (initial-st) isn't read-only.
(defthm initial-flags
  (and (not (access edst (initial-st tx w) :read-only))
       (equal (access edst (initial-st tx w) :wants-nl) w)))

(defthm undo-all-empties
  (implies (not (access edst st :read-only))
           (not (consp (access edst (mv-nth 1 (do-undo st (+ 1 (len (access edst st :undo))))) :undo))))
  :hints (("Goal" :do-not-induct t :in-theory (disable undo-times))))

;; CLAIM A: undoing everything restores the starting text.
(defthm claim-a-holds
  (claim-a tx wants-nl ops)
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d () (hist-ok hist-val initial-st run-ops initial-ok run-ops-ok undo-times
                               hist-val-empty do-undo-ok do-undo undo-all-empties))
           :use (initial-ok
                 (:instance run-ops-ok (st (initial-st tx wants-nl)))
                 (:instance undo-all-empties (st (run-ops (initial-st tx wants-nl) ops)))
                 (:instance do-undo-ok
                            (st (run-ops (initial-st tx wants-nl) ops))
                            (c (+ 1 (len (access edst (run-ops (initial-st tx wants-nl) ops) :undo)))))
                 (:instance hist-val-empty
                            (st (mv-nth 1 (do-undo (run-ops (initial-st tx wants-nl) ops)
                                                   (+ 1 (len (access edst (run-ops (initial-st tx wants-nl) ops) :undo)))))))))))
