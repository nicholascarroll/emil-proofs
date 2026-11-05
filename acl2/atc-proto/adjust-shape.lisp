; Milestone 0: can ATC express adjustPoint's SHAPE? Shape A: same branches as emil.
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
(defmacro ret* (n) `(mv (c::sint-dec-const ,n) |px| |py|))

; ATC's generated proof fails if any path leaves a pointee unwritten while another
; path writes it (see docs/atc-reality-check.md), so unchanged paths write it back.
(defmacro keep-px (body) `(let ((|px| (c::sint-write (c::sint-read |px|)))) ,body))
(defmacro keep-py (body) `(let ((|py| (c::sint-write (c::sint-read |py|)))) ,body))

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
  (let ((|lines_delta| (c::declar (c::sub-sint-sint |endy| |starty|))))
    (if (c::boolean-from-sint |is_delete|)
        ;; Deletion
        (if (or (lt* (c::sint-read |py|) |starty|)
                (and (eq* (c::sint-read |py|) |starty|)
                     (le* (c::sint-read |px|) |startx|)))
            (keep-px (keep-py (ret* 0)))
          (if (or (lt* (c::sint-read |py|) |endy|)
                  (and (eq* (c::sint-read |py|) |endy|)
                       (le* (c::sint-read |px|) |endx|)))
              (let* ((|px| (c::sint-write |startx|))
                     (|py| (c::sint-write |starty|)))
                (ret* 1))
            (if (eq* (c::sint-read |py|) |endy|)
                (let* ((|px| (c::sint-write
                              (c::add-sint-sint
                               |startx|
                               (c::sub-sint-sint (c::sint-read |px|) |endx|))))
                       (|py| (c::sint-write |starty|)))
                  (ret* 0))
              (keep-px
               (let ((|py| (c::sint-write
                            (c::sub-sint-sint (c::sint-read |py|) |lines_delta|))))
                 (ret* 0))))))
      ;; Insertion
      (if (or (lt* (c::sint-read |py|) |starty|)
              (and (eq* (c::sint-read |py|) |starty|)
                   (le* (c::sint-read |px|) |startx|)))
          (keep-px (keep-py (ret* 0)))
        (if (eq* (c::sint-read |py|) |starty|)
            (if (eq* |lines_delta| (c::sint-dec-const 0))
                (let ((|px| (c::sint-write
                             (c::add-sint-sint
                              (c::sint-read |px|)
                              (c::sub-sint-sint |endx| |startx|)))))
                  (keep-py (ret* 0)))
              (let* ((|px| (c::sint-write
                            (c::add-sint-sint
                             |endx|
                             (c::sub-sint-sint (c::sint-read |px|) |startx|))))
                     (|py| (c::sint-write
                            (c::add-sint-sint (c::sint-read |py|) |lines_delta|))))
                (ret* 0)))
          (keep-px
           (let ((|py| (c::sint-write
                        (c::add-sint-sint (c::sint-read |py|) |lines_delta|))))
             (ret* 0))))))))

(c::atc |adjustPoint| :file-name "adjust_shape" :header t)
