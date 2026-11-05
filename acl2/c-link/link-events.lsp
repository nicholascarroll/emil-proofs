;; Appended to the replay book by scripts/atc-replay.sh. No ATC and no trust tags in scope.
;; Each theorem: in any C computation state, under the guard, running the generated C
;; function leaves the state unchanged and returns an int whose value is adjust-spec's.

(defthm adjust_new_x-c-matches-spec
  (implies (and (c::compustatep c::compst)
                (equal c::fenv (c::init-fun-env (c::preprocess c::*program*)))
                (adjust-c-guard)
                (integerp c::limit)
                (>= c::limit @LIMIT(adjust_new_x)))
           (let ((res (c::exec-fun (c::ident "adjust_new_x")
                                   (list |x| |y| |startx| |starty| |endx| |endy| |is_delete|)
                                   c::compst c::fenv c::limit)))
             (and (equal (mv-nth 1 res) c::compst)
                  (c::sintp (mv-nth 0 res))
                  (equal (c::integer-from-sint (mv-nth 0 res))
                         (adj-x (spec-at-c-values))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (mv-nth) (|adjust_new_x|))
           :use (c::|*PROGRAM*-adjust_new_x-CORRECT| adjust_new_x-matches-spec))))

(defthm adjust_new_y-c-matches-spec
  (implies (and (c::compustatep c::compst)
                (equal c::fenv (c::init-fun-env (c::preprocess c::*program*)))
                (adjust-c-guard)
                (integerp c::limit)
                (>= c::limit @LIMIT(adjust_new_y)))
           (let ((res (c::exec-fun (c::ident "adjust_new_y")
                                   (list |x| |y| |startx| |starty| |endx| |endy| |is_delete|)
                                   c::compst c::fenv c::limit)))
             (and (equal (mv-nth 1 res) c::compst)
                  (c::sintp (mv-nth 0 res))
                  (equal (c::integer-from-sint (mv-nth 0 res))
                         (adj-y (spec-at-c-values))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (mv-nth) (|adjust_new_y|))
           :use (c::|*PROGRAM*-adjust_new_y-CORRECT| adjust_new_y-matches-spec))))

(defthm adjust_clamped-c-matches-spec
  (implies (and (c::compustatep c::compst)
                (equal c::fenv (c::init-fun-env (c::preprocess c::*program*)))
                (adjust-c-guard)
                (integerp c::limit)
                (>= c::limit @LIMIT(adjust_clamped)))
           (let ((res (c::exec-fun (c::ident "adjust_clamped")
                                   (list |x| |y| |startx| |starty| |endx| |endy| |is_delete|)
                                   c::compst c::fenv c::limit)))
             (and (equal (mv-nth 1 res) c::compst)
                  (c::sintp (mv-nth 0 res))
                  (equal (c::integer-from-sint (mv-nth 0 res))
                         (adj-ret (spec-at-c-values))))))
  :hints (("Goal" :do-not-induct t
           :in-theory (e/d (mv-nth) (|adjust_clamped|))
           :use (c::|*PROGRAM*-adjust_clamped-CORRECT| adjust_clamped-matches-spec))))

;; Show the generated theorems' statements in the certification log
(defconst *link-check* :link-events-admitted)
