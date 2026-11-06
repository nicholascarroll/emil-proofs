#!/usr/bin/env python3
"""Seed bugs in the model. For each: which claims become false on the small exhaustive domain,
and does the proof chain still certify?  Usage: seed-proofs.py REPO WORK TOOLS"""
import os, re, shutil, subprocess, sys
root, work, tools = sys.argv[1:4]
src = open(root + '/tests/undo/seed-model.py').read()
MODEL = eval(src[src.index('MODEL = [')+8:src.index('CBUGS = [')])
EXTRA = [
 ("merge at any position", "(if (and (equal p-ex n-sx) (equal p-ey n-sy)) :append :none)",
  "(if (or (equal p-ex n-sx) (equal p-ey n-sy) t) :append :none)"),
 ("delete record's data wrong", "(make-undo-rec sx sy ex ey t old co", "(make-undo-rec sx sy ex ey t (cdr old) co"),
 ("redo applies only first of group", "(if (and (consp redo) (access undo-rec (car redo) :paired))", "(if (and nil (consp redo))"),
 ("undo stops after first of group", "(if paired\n            (undo-group st1)", "(if (and paired nil)\n            (undo-group st1)"),
 ("repair replaces instead of inserting", ":text (insert-data tx x y data)", ":text (prog2$ data tx)"),
]
CHECK = '''(set-inhibit-output-lst '(prove proof-tree event summary warning warning! observation))
(ld "%s/undo/diff/check-statements.lsp" :ld-pre-eval-print nil :ld-post-eval-print nil :ld-verbose nil)
(mv-let (f n) (run-all-texts *texts* t 3 *small-ops* 0 0) (cw "~%%S1 ~x0 ~x1~%%" f n))
(mv-let (f n) (run-all-texts *texts* nil 3 *small-ops* 0 0) (cw "~%%S2 ~x0 ~x1~%%" f n))
(mv-let (f n u) (run-c-texts *texts* t 0 0 0) (cw "~%%S3 ~x0 ~x1 ~x2~%%" f n u))
(good-bye 0)
'''
print("| Bug seeded in the model | Claims false on the small domain | Proofs |")
print("|---|---|---|")
for i, (name, a, b) in enumerate(MODEL + EXTRA):
    d = f'{work}/s{i}'
    shutil.copytree(root + '/acl2/claims', d + '/claims', ignore=shutil.ignore_patterns('*.out', '*.time'))
    shutil.copytree(root + '/acl2/undo', d + '/undo', ignore=shutil.ignore_patterns('*.out', '*.time', '*.cert', '*.fasl', '*.port'))
    p = d + '/undo/model.lisp'; s = open(p).read()
    if a not in s:
        print(f"| {name} | patch did not apply | |", flush=True); continue
    open(p, 'w').write(s.replace(a, b))
    open(d + '/check.lsp', 'w').write(CHECK % d)
    r = subprocess.run([tools + '/acl2/saved_acl2'], stdin=open(d + '/check.lsp'), capture_output=True, text=True, timeout=500)
    fails = set(re.findall(r'FAIL (R|A|B1|B2|C) ', r.stdout))
    bad = 'ERROR' if re.search(r'ACL2 Error|HARD ACL2', r.stdout) and not re.search(r'S1 \d', r.stdout) else ''
    env = dict(os.environ, ACL2_SYSTEM_BOOKS=tools + '/acl2/books')
    subprocess.run([tools + '/acl2/books/build/cert.pl', '--acl2', tools + '/acl2/saved_acl2', 'coalesce.lisp'],
                   cwd=d + '/undo', env=env, capture_output=True, text=True, timeout=600)
    failed = 'certify'
    for bk in ('model', 'statements', 'text', 'history', 'redo', 'coalesce'):
        if not os.path.exists(f'{d}/undo/{bk}.cert'):
            t = ''
            try: t = open(f'{d}/undo/{bk}.cert.out', errors='replace').read()
            except FileNotFoundError: pass
            m = re.search(r'ACL2 Error[^\n]*in \( ?(\S+ \S+)', t)
            failed = f"fail in {bk}" + (f": {m.group(1)}" if m else '')
            break
    print(f"| {name} | {bad or (', '.join(sorted(fails)) if fails else 'none')} | {failed} |", flush=True)
