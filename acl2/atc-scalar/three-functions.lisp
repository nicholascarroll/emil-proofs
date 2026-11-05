; Pointer-free prototype F: three functions of scalars, one per output.
;
; Prototype only and NOT evidence for any claim. The 10^9 bound is a prototype
; convenience; the real bounds are a Milestone 2 question.
(in-package "ACL2")

(include-book "kestrel/c/atc/atc" :dir :system :ttags ((:quicklisp) (:quicklisp.osicat) (:oslib) (:open-output-channel!) (:file-io!)))

(defmacro in-bounds (x)
  `(and (<= 0 (c::integer-from-sint ,x))
        (<= (c::integer-from-sint ,x) 1000000000)))
(defmacro lt* (a b) `(c::boolean-from-sint (c::lt-sint-sint ,a ,b)))
(defmacro le* (a b) `(c::boolean-from-sint (c::le-sint-sint ,a ,b)))
(defmacro eq* (a b) `(c::boolean-from-sint (c::eq-sint-sint ,a ,b)))
(defmacro scalar-guard ()
  `(and (c::sintp |x|) (c::sintp |y|) (c::sintp |startx|) (c::sintp |starty|)
        (c::sintp |endx|) (c::sintp |endy|) (c::sintp |is_delete|)
        (in-bounds |x|) (in-bounds |y|) (in-bounds |startx|)
        (in-bounds |starty|) (in-bounds |endx|) (in-bounds |endy|)))
(defun |adjust_new_x| (|x| |y| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (scalar-guard) :guard-hints (("Goal" :in-theory (enable c::declar
                                                    c::add-sint-sint c::sub-sint-sint
                                                    c::add-sint-sint-okp c::sub-sint-sint-okp
                                                    c::sint-integerp-alt-def c::sint-integer-fix
                                                    c::sint-min c::sint-max c::int-bits)))))
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
  (declare (xargs :guard (scalar-guard) :guard-hints (("Goal" :in-theory (enable c::declar
                                                    c::add-sint-sint c::sub-sint-sint
                                                    c::add-sint-sint-okp c::sub-sint-sint-okp
                                                    c::sint-integerp-alt-def c::sint-integer-fix
                                                    c::sint-min c::sint-max c::int-bits)))))
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
  (declare (xargs :guard (scalar-guard) :guard-hints (("Goal" :in-theory (enable c::declar
                                                    c::add-sint-sint c::sub-sint-sint
                                                    c::add-sint-sint-okp c::sub-sint-sint-okp
                                                    c::sint-integerp-alt-def c::sint-integer-fix
                                                    c::sint-min c::sint-max c::int-bits)))))
  (if (c::boolean-from-sint |is_delete|)
      (if (or (lt* |y| |starty|)
              (and (eq* |y| |starty|) (le* |x| |startx|)))
          (c::sint-dec-const 0)
        (if (or (lt* |y| |endy|)
                (and (eq* |y| |endy|) (le* |x| |endx|)))
            (c::sint-dec-const 1)
          (c::sint-dec-const 0)))
    (c::sint-dec-const 0)))

(c::atc |adjust_new_x| |adjust_new_y| |adjust_clamped| :file-name "adjust_scalar" :header t)
