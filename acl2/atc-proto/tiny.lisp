; Milestone 0: the smallest ATC run. Not evidence for any claim.
(in-package "ACL2")

(include-book "kestrel/c/atc/atc" :dir :system :ttags ((:quicklisp) (:quicklisp.osicat) (:oslib) (:open-output-channel!) (:file-io!)))

(defun |add_one| (|x|)
  (declare (xargs :guard (and (c::sintp |x|)
                              (<= 0 (c::integer-from-sint |x|))
                              (<= (c::integer-from-sint |x|) 100))
                  :guard-hints (("Goal" :in-theory (enable c::add-sint-sint-okp
                                                           c::sint-integerp-alt-def)))))
  (c::add-sint-sint |x| (c::sint-dec-const 1)))

(c::atc |add_one| :file-name "tiny" :header t)
