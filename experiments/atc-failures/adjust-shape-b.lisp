; Milestone 0: can ATC express adjustPoint's SHAPE? Shape B: locals and a single exit.
;
; This is a shape prototype only and is NOT evidence for any claim.
; In particular the bound 10^9 below is a convenience for the prototype. The real
; arithmetic-safety bounds are a Milestone 2 decision, for the owner to review.
(in-package "ACL2")

(include-book "kestrel/c/atc/atc" :dir :system :ttags ((:quicklisp) (:quicklisp.osicat) (:oslib) (:open-output-channel!) (:file-io!)))

(defmacro proto-in-bounds (x)
  `(and (<= 0 (c::integer-from-sint ,x))
        (<= (c::integer-from-sint ,x) 1000000000)))

(defmacro lt* (a b) `(c::boolean-from-sint (c::lt-sint-sint ,a ,b)))
(defmacro le* (a b) `(c::boolean-from-sint (c::le-sint-sint ,a ,b)))
(defmacro eq* (a b) `(c::boolean-from-sint (c::eq-sint-sint ,a ,b)))
(defmacro same* () `(mv |x| |y| |r|))

(defun |adjustPoint| (|px| |py| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (and (c::star (c::sintp |px|))
                              (c::star (c::sintp |py|))
                              (c::sintp |startx|)
                              (c::sintp |starty|)
                              (c::sintp |endx|)
                              (c::sintp |endy|)
                              (c::sintp |is_delete|)
                              (proto-in-bounds |px|)
                              (proto-in-bounds |py|)
                              (proto-in-bounds |startx|)
                              (proto-in-bounds |starty|)
                              (proto-in-bounds |endx|)
                              (proto-in-bounds |endy|))
                  :guard-hints (("Goal"
                                 :in-theory (enable c::declar
                                                    c::assign
                                                    c::sint-read
                                                    c::sint-write
                                                    c::add-sint-sint
                                                    c::sub-sint-sint
                                                    c::add-sint-sint-okp
                                                    c::sub-sint-sint-okp
                                                    c::sint-integerp-alt-def
                                                    c::sint-integer-fix
                                                    c::sint-min
                                                    c::sint-max
                                                    c::int-bits)))))
  (let* ((|x| (c::declar (c::sint-read |px|)))
         (|y| (c::declar (c::sint-read |py|)))
         (|r| (c::declar (c::sint-dec-const 0)))
         (|lines_delta| (c::declar (c::sub-sint-sint |endy| |starty|))))
    (mv-let (|x| |y| |r|)
      (if (c::boolean-from-sint |is_delete|)
          ;; Deletion
          (if (or (lt* |y| |starty|)
                  (and (eq* |y| |starty|) (le* |x| |startx|)))
              (same*)
            (if (or (lt* |y| |endy|)
                    (and (eq* |y| |endy|) (le* |x| |endx|)))
                (let* ((|x| (c::assign |startx|))
                       (|y| (c::assign |starty|))
                       (|r| (c::assign (c::sint-dec-const 1))))
                  (same*))
              (if (eq* |y| |endy|)
                  (let* ((|x| (c::assign
                               (c::add-sint-sint
                                |startx| (c::sub-sint-sint |x| |endx|))))
                         (|y| (c::assign |starty|)))
                    (same*))
                (let ((|y| (c::assign (c::sub-sint-sint |y| |lines_delta|))))
                  (same*)))))
        ;; Insertion
        (if (or (lt* |y| |starty|)
                (and (eq* |y| |starty|) (le* |x| |startx|)))
            (same*)
          (if (eq* |y| |starty|)
              (if (eq* |lines_delta| (c::sint-dec-const 0))
                  (let ((|x| (c::assign
                              (c::add-sint-sint
                               |x| (c::sub-sint-sint |endx| |startx|)))))
                    (same*))
                (let* ((|x| (c::assign
                             (c::add-sint-sint
                              |endx| (c::sub-sint-sint |x| |startx|))))
                       (|y| (c::assign (c::add-sint-sint |y| |lines_delta|))))
                  (same*)))
            (let ((|y| (c::assign (c::add-sint-sint |y| |lines_delta|))))
              (same*)))))
      (let* ((|px| (c::sint-write |x|))
             (|py| (c::sint-write |y|)))
        (mv |r| |px| |py|)))))

(c::atc |adjustPoint| :file-name "adjust_shape_b" :header t)
