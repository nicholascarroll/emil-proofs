; Timeboxed check: parse the generated C with C$ and compare with *program*.
; Evidence about one output file. It is not a proof of the printer.
; Run from a directory holding copies of adjust_scalar.c and adjust_scalar.h.
(include-book "kestrel/c/portcullis" :dir :system)
(include-book "kestrel/c/syntax/input-files" :dir :system :ttags :all)
(include-book "kestrel/c/syntax/abstract-syntax-formal-mapping-direct" :dir :system :ttags :all)
(include-book "REPLAY" :ttags :all)
(in-package "C$")
(input-files :files '("adjust_scalar.c") :process :disambiguate :const *parsed-c*)
(input-files :files '("adjust_scalar.h") :process :disambiguate :const *parsed-h*)
(mv-let (erp mapped) (ldm-trans-ensemble (code-ensemble->trans-units *parsed-c*))
  (mv-let (erp2 mapped-h) (ldm-trans-ensemble (code-ensemble->trans-units *parsed-h*))
    (progn$
     (cw "ROUNDTRIP c-map-error: ~x0~%" erp)
     (cw "ROUNDTRIP h-map-error: ~x0~%" erp2)
     (cw "ROUNDTRIP dot-c identical: ~x0~%"
         (equal (c::trans-ensemble->dot-c mapped) (c::trans-ensemble->dot-c c::*program*)))
     (cw "ROUNDTRIP dot-h identical: ~x0~%"
         (equal (c::trans-ensemble->dot-c mapped-h) (c::trans-ensemble->dot-h c::*program*)))
     (cw "ROUNDTRIP-END~%"))))
(set-serialize-character nil state)
(mv-let (erp mapped) (ldm-trans-ensemble (code-ensemble->trans-units *parsed-c*))
  (declare (ignore erp))
  (mv-let (o state) (open-output-channel "cmp.txt" :object state)
    (pprogn (print-object$ (c::trans-ensemble->dot-c mapped) o state)
            (print-object$ (c::trans-ensemble->dot-c c::*program*) o state)
            (close-output-channel o state))))
