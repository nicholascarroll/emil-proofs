; Pointer-free version: ATC generates three C functions, one per output, from the
; functions in ../c-link/functions.lisp. This book is a generator: it runs ATC, so it uses
; trust tags, and no claim rests on it. Claims rest on its replay (scripts/atc-replay.sh).
(in-package "ACL2")

(include-book "kestrel/c/atc/atc" :dir :system :ttags ((:quicklisp) (:quicklisp.osicat) (:oslib) (:open-output-channel!) (:file-io!)))
(include-book "../c-link/functions")

(c::atc |adjust_new_x| |adjust_new_y| |adjust_clamped| :file-name "adjust_scalar" :header t)
