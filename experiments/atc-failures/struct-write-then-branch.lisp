; Pointer-free prototype S: a struct passed and returned by value.
;
; Prototype only and NOT evidence for any claim. The 10^9 bound is a prototype
; convenience; the real bounds are a Milestone 2 question.
(in-package "ACL2")

(include-book "kestrel/c/atc/atc" :dir :system :ttags ((:quicklisp) (:quicklisp.osicat) (:oslib) (:open-output-channel!) (:file-io!)))

(c::defstruct |adjust_result|
              (|x| c::sint)
              (|y| c::sint)
              (|clamped| c::sint))

(defmacro in-bounds (x)
  `(and (<= 0 (c::integer-from-sint ,x))
        (<= (c::integer-from-sint ,x) 1000000000)))
(defmacro lt* (a b) `(c::boolean-from-sint (c::lt-sint-sint ,a ,b)))
(defmacro le* (a b) `(c::boolean-from-sint (c::le-sint-sint ,a ,b)))
(defmacro eq* (a b) `(c::boolean-from-sint (c::eq-sint-sint ,a ,b)))
(defmacro rx (s) `(struct-|adjust_result|-read-|x| ,s))
(defmacro ry (s) `(struct-|adjust_result|-read-|y| ,s))
(defmacro wx (v s) `(struct-|adjust_result|-write-|x| ,v ,s))
(defmacro wy (v s) `(struct-|adjust_result|-write-|y| ,v ,s))
(defmacro wc (v s) `(struct-|adjust_result|-write-|clamped| ,v ,s))

(defun |adjust_value| (|s| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (and (struct-|adjust_result|-p |s|)
                              (c::sintp |startx|)
                              (c::sintp |starty|)
                              (c::sintp |endx|)
                              (c::sintp |endy|)
                              (c::sintp |is_delete|)
                              (in-bounds (rx |s|))
                              (in-bounds (ry |s|))
                              (in-bounds |startx|)
                              (in-bounds |starty|)
                              (in-bounds |endx|)
                              (in-bounds |endy|))
                  :guard-hints (("Goal"
                                 :in-theory (enable c::declar
                                                    c::assign
                                                    c::add-sint-sint
                                                    c::sub-sint-sint
                                                    c::add-sint-sint-okp
                                                    c::sub-sint-sint-okp
                                                    c::sint-integerp-alt-def
                                                    c::sint-integer-fix
                                                    c::sint-min
                                                    c::sint-max
                                                    c::int-bits)))))
  (let* ((|x| (c::declar (rx |s|)))
         (|y| (c::declar (ry |s|)))
         (|lines_delta| (c::declar (c::sub-sint-sint |endy| |starty|)))
         (|s| (wc (c::sint-dec-const 0) |s|)))
    (if (c::boolean-from-sint |is_delete|)
        (if (or (lt* |y| |starty|)
                (and (eq* |y| |starty|) (le* |x| |startx|)))
            |s|
          (if (or (lt* |y| |endy|)
                  (and (eq* |y| |endy|) (le* |x| |endx|)))
              (let* ((|s| (wx |startx| |s|))
                     (|s| (wy |starty| |s|))
                     (|s| (wc (c::sint-dec-const 1) |s|)))
                |s|)
            (if (eq* |y| |endy|)
                (let* ((|s| (wx (c::add-sint-sint |startx| (c::sub-sint-sint |x| |endx|)) |s|))
                       (|s| (wy |starty| |s|)))
                  |s|)
              (let ((|s| (wy (c::sub-sint-sint |y| |lines_delta|) |s|)))
                |s|))))
      (if (or (lt* |y| |starty|)
              (and (eq* |y| |starty|) (le* |x| |startx|)))
          |s|
        (if (eq* |y| |starty|)
            (if (eq* |lines_delta| (c::sint-dec-const 0))
                (let ((|s| (wx (c::add-sint-sint |x| (c::sub-sint-sint |endx| |startx|)) |s|)))
                  |s|)
              (let* ((|s| (wx (c::add-sint-sint |endx| (c::sub-sint-sint |x| |startx|)) |s|))
                     (|s| (wy (c::add-sint-sint |y| |lines_delta|) |s|)))
                |s|))
          (let ((|s| (wy (c::add-sint-sint |y| |lines_delta|) |s|)))
            |s|))))))

(c::atc |adjust_result| |adjust_value| :file-name "adjust_struct" :header t)
