; Milestone 3: the C-shaped ACL2 functions that ATC turns into C, and their link to the spec.
; No ATC and no trust tags, so these theorems can back claims.
(in-package "ACL2")

(include-book "kestrel/c/representation/integer-operations" :dir :system)
(include-book "kestrel/c/atc/let-designations" :dir :system)
(include-book "../claims/spec")
(local (include-book "arithmetic/top-with-meta" :dir :system))

(defmacro lt* (a b) `(c::boolean-from-sint (c::lt-sint-sint ,a ,b)))
(defmacro le* (a b) `(c::boolean-from-sint (c::le-sint-sint ,a ,b)))
(defmacro eq* (a b) `(c::boolean-from-sint (c::eq-sint-sint ,a ,b)))

;; The guard: every parameter is an int, and adjust-no-overflow-p holds at C's INT_MAX.
(defmacro adjust-c-guard ()
  `(and (c::sintp |x|) (c::sintp |y|) (c::sintp |startx|) (c::sintp |starty|)
        (c::sintp |endx|) (c::sintp |endy|) (c::sintp |is_delete|)
        (adjust-no-overflow-p (c::integer-from-sint |x|) (c::integer-from-sint |y|)
                              (c::integer-from-sint |startx|) (c::integer-from-sint |starty|)
                              (c::integer-from-sint |endx|) (c::integer-from-sint |endy|)
                              (c::boolean-from-sint |is_delete|) 2147483647)))

;; ---------- C operations as arithmetic ----------

(local (defthm c-lt
  (implies (and (c::sintp a) (c::sintp b))
           (equal (lt* a b) (< (c::integer-from-sint a) (c::integer-from-sint b))))
  :hints (("Goal" :in-theory (enable c::lt-sint-sint c::boolean-from-sint c::sint-from-boolean)))))
(local (defthm c-le
  (implies (and (c::sintp a) (c::sintp b))
           (equal (le* a b) (<= (c::integer-from-sint a) (c::integer-from-sint b))))
  :hints (("Goal" :in-theory (enable c::le-sint-sint c::boolean-from-sint c::sint-from-boolean)))))
(local (defthm c-eq
  (implies (and (c::sintp a) (c::sintp b))
           (equal (eq* a b) (equal (c::integer-from-sint a) (c::integer-from-sint b))))
  :hints (("Goal" :in-theory (enable c::eq-sint-sint c::boolean-from-sint c::sint-from-boolean)))))

(local (defthm c-int-range
  (implies (c::sintp a)
           (and (<= -2147483648 (c::integer-from-sint a))
                (<= (c::integer-from-sint a) 2147483647)))
  :hints (("Goal" :in-theory (enable c::sint-integerp-alt-def c::sint-min c::sint-max c::int-bits)))
  :rule-classes :linear))

(local (defthm c-okp-add
  (implies (and (c::sintp a) (c::sintp b))
           (equal (c::add-sint-sint-okp a b)
                  (and (<= -2147483648 (+ (c::integer-from-sint a) (c::integer-from-sint b)))
                       (<= (+ (c::integer-from-sint a) (c::integer-from-sint b)) 2147483647))))
  :hints (("Goal" :in-theory (enable c::add-sint-sint-okp c::sint-integerp-alt-def
                                     c::sint-min c::sint-max c::int-bits)))))
(local (defthm c-okp-sub
  (implies (and (c::sintp a) (c::sintp b))
           (equal (c::sub-sint-sint-okp a b)
                  (and (<= -2147483648 (- (c::integer-from-sint a) (c::integer-from-sint b)))
                       (<= (- (c::integer-from-sint a) (c::integer-from-sint b)) 2147483647))))
  :hints (("Goal" :in-theory (enable c::sub-sint-sint-okp c::sint-integerp-alt-def
                                     c::sint-min c::sint-max c::int-bits)))))
(local (defthm c-value-add
  (implies (and (c::sintp a) (c::sintp b)
                (<= -2147483648 (+ (c::integer-from-sint a) (c::integer-from-sint b)))
                (<= (+ (c::integer-from-sint a) (c::integer-from-sint b)) 2147483647))
           (equal (c::integer-from-sint (c::add-sint-sint a b))
                  (+ (c::integer-from-sint a) (c::integer-from-sint b))))
  :hints (("Goal" :in-theory (enable c::add-sint-sint c::sint-integerp-alt-def
                                     c::sint-min c::sint-max c::int-bits)))))
(local (defthm c-value-sub
  (implies (and (c::sintp a) (c::sintp b)
                (<= -2147483648 (- (c::integer-from-sint a) (c::integer-from-sint b)))
                (<= (- (c::integer-from-sint a) (c::integer-from-sint b)) 2147483647))
           (equal (c::integer-from-sint (c::sub-sint-sint a b))
                  (- (c::integer-from-sint a) (c::integer-from-sint b))))
  :hints (("Goal" :in-theory (enable c::sub-sint-sint c::sint-integerp-alt-def
                                     c::sint-min c::sint-max c::int-bits)))))


;; ---------- The functions ATC turns into C ----------

(defun |adjust_new_x| (|x| |y| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (adjust-c-guard)
                  :guard-hints (("Goal" :do-not-induct t :in-theory (enable c::declar pos<=)))))
  (if (c::boolean-from-sint |is_delete|)
      (if (or (lt* |y| |starty|)
              (and (eq* |y| |starty|) (le* |x| |startx|)))
          |x|
        (if (or (lt* |y| |endy|)
                (and (eq* |y| |endy|) (le* |x| |endx|)))
            |startx|
          (if (eq* |y| |endy|)
              (c::add-sint-sint |startx| (c::sub-sint-sint |x| |endx|))
            |x|)))
    (if (or (lt* |y| |starty|)
            (and (eq* |y| |starty|) (le* |x| |startx|)))
        |x|
      (if (eq* |y| |starty|)
          (if (eq* |endy| |starty|)
              (c::add-sint-sint |x| (c::sub-sint-sint |endx| |startx|))
            (c::add-sint-sint |endx| (c::sub-sint-sint |x| |startx|)))
        |x|))))

(defun |adjust_new_y| (|x| |y| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (adjust-c-guard)
                  :guard-hints (("Goal" :do-not-induct t :in-theory (enable c::declar pos<=)))))
  (let ((|lines_delta| (c::declar (c::sub-sint-sint |endy| |starty|))))
    (if (c::boolean-from-sint |is_delete|)
        (if (or (lt* |y| |starty|)
                (and (eq* |y| |starty|) (le* |x| |startx|)))
            |y|
          (if (or (lt* |y| |endy|)
                  (and (eq* |y| |endy|) (le* |x| |endx|)))
              |starty|
            (if (eq* |y| |endy|)
                |starty|
              (c::sub-sint-sint |y| |lines_delta|))))
      (if (or (lt* |y| |starty|)
              (and (eq* |y| |starty|) (le* |x| |startx|)))
          |y|
        (c::add-sint-sint |y| |lines_delta|)))))

(defun |adjust_clamped| (|x| |y| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (adjust-c-guard)
                  :guard-hints (("Goal" :do-not-induct t :in-theory (enable c::declar pos<=)))))
  (if (c::boolean-from-sint |is_delete|)
      (if (or (lt* |y| |starty|)
              (and (eq* |y| |starty|) (le* |x| |startx|)))
          (c::sint-dec-const 0)
        (if (or (lt* |y| |endy|)
                (and (eq* |y| |endy|) (le* |x| |endx|)))
            (c::sint-dec-const 1)
          (c::sint-dec-const 0)))
    (c::sint-dec-const 0)))

;; ---------- S1: the C-shaped functions equal the spec ----------

(defmacro spec-at-c-values ()
  `(adjust-spec (c::integer-from-sint |x|) (c::integer-from-sint |y|)
                (c::integer-from-sint |startx|) (c::integer-from-sint |starty|)
                (c::integer-from-sint |endx|) (c::integer-from-sint |endy|)
                (c::boolean-from-sint |is_delete|)))

(defthm adjust_new_x-matches-spec
  (implies (adjust-c-guard)
           (and (c::sintp (|adjust_new_x| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                (equal (c::integer-from-sint
                        (|adjust_new_x| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                       (adj-x (spec-at-c-values)))))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=))))

(defthm adjust_new_y-matches-spec
  (implies (adjust-c-guard)
           (and (c::sintp (|adjust_new_y| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                (equal (c::integer-from-sint
                        (|adjust_new_y| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                       (adj-y (spec-at-c-values)))))
  :hints (("Goal" :do-not-induct t :in-theory (enable c::declar pos<=))))

(defthm adjust_clamped-matches-spec
  (implies (adjust-c-guard)
           (and (c::sintp (|adjust_clamped| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                (equal (c::integer-from-sint
                        (|adjust_clamped| |x| |y| |startx| |starty| |endx| |endy| |is_delete|))
                       (adj-ret (spec-at-c-values)))))
  :hints (("Goal" :do-not-induct t :in-theory (enable pos<=))))

;; The guard can be met by real C values
(defthm adjust-c-guard-is-satisfiable
  (let ((|x| (c::sint-dec-const 0)) (|y| (c::sint-dec-const 0))
        (|startx| (c::sint-dec-const 0)) (|starty| (c::sint-dec-const 0))
        (|endx| (c::sint-dec-const 0)) (|endy| (c::sint-dec-const 0))
        (|is_delete| (c::sint-dec-const 0)))
    (adjust-c-guard)))
