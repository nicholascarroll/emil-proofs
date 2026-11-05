; Milestone 0: smallest possible certification check. No ATC, no trust tags.
(in-package "ACL2")

(defun app2 (x y)
  (if (endp x) y (cons (car x) (app2 (cdr x) y))))

(defthm app2-assoc
  (equal (app2 (app2 a b) c) (app2 a (app2 b c))))
