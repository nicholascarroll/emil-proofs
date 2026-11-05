; Replays a trace from tests/undo/driver.c on the ACL2 model and compares each step.
; Test tooling, not a claim.  Loaded with ld; never certified or cited.
(in-package "ACL2")
(include-book "../model")
(set-guard-checking :none)
(set-state-ok t)
(program)

(defun rec->list (r)
  (list (access undo-rec r :sx) (access undo-rec r :sy)
        (access undo-rec r :ex) (access undo-rec r :ey)
        (access undo-rec r :del) (access undo-rec r :data)
        (access undo-rec r :app) (access undo-rec r :paired)
        (access undo-rec r :nmerges) (access undo-rec r :uncapped)
        (access undo-rec r :px) (access undo-rec r :py)))

(defun recs->lists (rs)
  (if (endp rs) nil (cons (rec->list (car rs)) (recs->lists (cdr rs)))))

(defun recs-head (rs) (if (consp rs) (list (rec->list (car rs))) nil))

(defun result-code (r)
  (case r (:done 0) (:exhausted 1) (:refused 2) (otherwise -9)))

;; Returns (mv r1 r2 st)
(defun apply-edit (st sx sy ex ey repl chain coalesce burst want-end)
  (let* ((ref (edit-refusal st sx sy ex ey repl))
         (st2 (edit st sx sy ex ey repl chain coalesce burst)))
    (if (or ref (not want-end))
        (mv -1 -1 st2)
      (if (consp repl)
          (mv (data-end-x sx repl) (data-end-y sy repl) st2)
        (mv sx sy st2)))))

(defun apply-op (st o)
  (let ((k (nth 0 o)) (sx (nth 1 o)) (sy (nth 2 o)) (ex (nth 3 o)) (ey (nth 4 o))
        (flag (nth 5 o)) (burst (not (equal (nth 6 o) 0))) (data (nth 8 o)))
    (case k
      (:ins-char (apply-edit st sx sy sx sy data nil t burst t))
      (:del-char (apply-edit st sx sy ex ey nil nil t burst nil))
      (:insert (apply-edit st sx sy sx sy data nil nil nil t))
      (:delete (apply-edit st sx sy ex ey nil nil nil nil nil))
      (:replace (apply-edit st sx sy ex ey data (not (equal flag 0)) nil nil t))
      (:extend (mv -1 -1 (extend-rows st sx flag)))
      (:undo (mv-let (r st2) (do-undo st flag) (mv (result-code r) -1 st2)))
      (:redo (mv-let (r st2) (do-redo st flag) (mv (result-code r) -1 st2)))
      (:cursor (mv -1 -1 (change edst st :cx sx :cy sy)))
      (:close (mv -1 -1 (change edst st :undo (close-run (access edst st :undo)))))
      (:clear (mv -1 -1 (change edst st :undo nil :redo nil)))
      (:readonly (mv -1 -1 (change edst st :read-only (not (equal flag 0)))))
      (otherwise (mv -9 -9 st)))))

;; The first field where model and C differ, or nil.  (field model c)
(defun first-diff (r1 r2 st step)
  (let ((c-r1 (nth 2 step)) (c-r2 (nth 3 step)) (c-cx (nth 4 step)) (c-cy (nth 5 step))
        (c-text (nth 6 step)) (c-nundo (nth 7 step)) (c-nredo (nth 8 step))
        (full (nth 9 step)) (c-undo (nth 10 step)) (c-redo (nth 11 step))
        (undo (access edst st :undo)) (redo (access edst st :redo)))
    (cond ((not (equal (access edst st :text) c-text))
           (list :text (access edst st :text) c-text))
          ((not (equal (len undo) c-nundo)) (list :nundo (len undo) c-nundo))
          ((not (equal (len redo) c-nredo)) (list :nredo (len redo) c-nredo))
          ((not (equal (if full (recs->lists undo) (recs-head undo)) c-undo))
           (list :undo (if full (recs->lists undo) (recs-head undo)) c-undo))
          ((not (equal (if full (recs->lists redo) (recs-head redo)) c-redo))
           (list :redo (if full (recs->lists redo) (recs-head redo)) c-redo))
          ((not (equal r1 c-r1)) (list :r1 r1 c-r1))
          ((not (equal r2 c-r2)) (list :r2 r2 c-r2))
          ((not (equal (access edst st :cx) c-cx)) (list :cx (access edst st :cx) c-cx))
          ((not (equal (access edst st :cy) c-cy)) (list :cy (access edst st :cy) c-cy))
          (t nil))))

(defconst *undo-all* 100000)
(defun norm-count (c) (if (zp c) 1 c))

;; Claims A and B as checks on the trace, so on C's text as well as the model's.
;; PREV-OP and PREV-R1 describe the last step, BEFORE-UNDO the text before it.
(defun prop-diff (o r1 c-text initial prev-op prev-r1 before-undo before-nredo nundo)
  (cond ((and (equal (nth 0 o) :undo) (equal r1 1) (equal nundo 0)
              (not (equal c-text initial)))
         :a-undo-all-not-original)
        ((and (equal (nth 0 o) :redo) (consp prev-op) (equal (nth 0 prev-op) :undo)
              (equal (norm-count (nth 5 o)) (norm-count (nth 5 prev-op)))
              (or (and (equal prev-r1 0) (equal r1 0))
                  ;; undo everything, redo everything: only comparable if nothing
                  ;; was already waiting on the redo list
                  (and (equal prev-r1 1) (equal r1 1) (equal before-nredo 0)
                       (>= (norm-count (nth 5 o)) *undo-all*)))
              (not (equal c-text before-undo)))
         :b-redo-after-undo-differs)
        (t nil)))

(defun check-loop (chan st seed mode initial prev-op prev-r1 before-undo before-nredo nsteps
                        cursor-bad state)
  (mv-let (eof step state)
    (read-object chan state)
    (cond
     (eof (mv :crash nsteps cursor-bad state))
     ((equal step '(:end)) (mv :ok nsteps cursor-bad state))
     (t
      (let ((o (nth 1 step)) (text-before (access edst st :text)))
        (mv-let (r1 r2 st2)
          (apply-op st o)
          (let* ((d (first-diff r1 r2 st2 step))
                 (c-text (nth 6 step))
                 (p (and (not d)
                         (prop-diff o r1 c-text initial prev-op prev-r1 before-undo
                                    before-nredo (nth 7 step))))
                 (hist-bad (and (not d) (not p) (nth 9 step)
                                (not (history-matches-p st2))))
                 (cursor-now-bad (and (member-equal (nth 0 o) '(:undo :redo))
                                      (not (valid-pos-p (access edst st2 :cx)
                                                   (access edst st2 :cy) c-text)))))
            (cond
             (d (prog2$ (cw "~%DIFF ~x0 ~s1 step ~x2 field ~x3~%  op ~x4~%  before ~x5~%  model ~x6~%  c     ~x7~%"
                            seed mode (nth 0 step)
                            (car d) o text-before (cadr d) (caddr d))
                        (mv :diff nsteps cursor-bad state)))
             (p (prog2$ (cw "~%PROP ~x0 ~s1 step ~x2 ~x3~%  op ~x4~%  text ~x5~%"
                            seed mode (nth 0 step) p o c-text)
                        (mv :prop nsteps cursor-bad state)))
             (hist-bad
              (prog2$ (cw "~%HIST ~x0 ~s1 step ~x2~%  op ~x3~%" seed mode (nth 0 step) o)
                      (mv :hist nsteps cursor-bad state)))
             (t
              (check-loop chan st2 seed mode
                          (if (equal (nth 0 o) :clear) c-text initial)
                          o r1 text-before (len (access edst st :redo)) (+ 1 nsteps)
                          (if cursor-now-bad (+ 1 cursor-bad) cursor-bad)
                          state))))))))))

(defun check-file (file state)
  (mv-let (chan state)
    (open-input-channel file :object state)
    (if (not chan)
        (prog2$ (cw "NOFILE ~s0~%" file) (mv :nofile state))
      (mv-let (eof hdr state)
        (read-object chan state)
        (if (or eof (not (equal (car hdr) :start)))
            (let ((state (close-input-channel chan state)))
              (prog2$ (cw "BADHEADER ~s0~%" file) (mv :badheader state)))
          (let* ((seed (nth 1 hdr)) (mode (nth 2 hdr)) (tx (nth 4 hdr))
                 (st (make edst :text tx :undo nil :redo nil :cx 0 :cy 0
                           :wants-nl (nth 3 hdr) :read-only nil)))
            (mv-let (res n cursor-bad state)
              (check-loop chan st seed mode tx nil nil nil 0 0 0 state)
              (let ((state (close-input-channel chan state)))
                (prog2$ (cw "~%RESULT ~x0 ~s1 ~x2 steps ~x3 cursor-bad ~x4~%"
                            seed mode res n cursor-bad)
                        (mv res state))))))))))

(defun check-files (files state)
  (if (endp files)
      state
    (mv-let (r state)
      (check-file (car files) state)
      (declare (ignore r))
      (check-files (cdr files) state))))
