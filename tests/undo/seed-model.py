#!/usr/bin/env python3
"""Seed bugs in the ACL2 model and in emil's C; the differential test must notice each.
Usage: seed-model.py REPO_ROOT WORK_DIR DRIVER        (model bugs, using the real driver)
       seed-model.py --c REPO_ROOT WORK_DIR EMIL COMMIT   (C bugs, against the real model)
"""
import os, re, shutil, subprocess, sys
MODEL = [
 ("merge limit 19",            '(defconst *undo-merge-limit* 20)', '(defconst *undo-merge-limit* 19)'),
 ("repair record not paired",  'nil data nil t nil 0 -1)', 'nil data nil nil nil 0 -1)'),
 ("backspace appends",         '((and (equal p-sx n-ex) (equal p-sy n-ey)) :prepend)', '((and (equal p-sx n-ex) (equal p-sy n-ey)) :append)'),
 ("undo ignores saved point",  '(recorded (and (integerp py) (<= 0 py)))', '(recorded nil)'),
 ("redo doesn't carry point",  '(redo-rest (redo-step st) (adj-x a) (adj-y a))', '(prog2$ a (redo-rest (redo-step st) px py))'),
 ("delete ignores chain",      'old co (and chain t)', 'old co nil'),
 ("final newline delete allowed", ':final-newline)\n          (t nil)', 'nil)\n          (t nil)'),
 ("burst ignored",             '(uncapped (and co burst))', '(uncapped nil)'),
 ("undo leaves run open (expected equivalent)", ':undo (close-run (cdr undo))', ':undo (cdr undo)'),
 ("merge ignores append flag", '(cond ((not (access undo-rec prev :app)) :none)', '(cond ((not t) :none)'),
 ("edit keeps redo",           ':text tx :undo undo :redo nil))', ':text tx :undo undo))'),
 ("extend anchored a row early", '(y (- from 1))', '(y (max 0 (- from 2)))'),
 ("repair skipped",            '(if (and (access edst st :wants-nl) (consp lastrow))', '(if (and nil (consp lastrow))'),
 ("insert end off by one",     '(defun data-end-x (sx data) (insert-end-x sx (split-lines data)))', '(defun data-end-x (sx data) (+ 1 (insert-end-x sx (split-lines data))))'),
]
CBUGS = [
 ("merge limit 19",            'undo.c', '#define UNDO_MERGE_LIMIT 20', '#define UNDO_MERGE_LIMIT 19'),
 ("repair not paired",         'mutate.c', 'fix->paired = 1;', 'fix->paired = 0;'),
 ("no repair",                 'mutate.c', '	restoreFinalNewline(buf);\n', ''),
 ("backspace merges at wrong end", 'undo.c', 'prepend = 1;', 'prepend = 0;'),
 ("end not recomputed on merge", 'undo.c', '	computeInsertEnd(prev->data, prev->datalen, prev->startx, prev->starty,\n			 &prev->endx, &prev->endy);\n', ''),
 ("redo keeps group apart",    'undo.c', 'while (buf->redo != NULL && buf->redo->paired) {', 'while (0) {'),
 ("undo leaves run open (expected equivalent)", 'undo.c', '	/* Close whatever now sits at the head of the undo list. */\n	undoCloseRun(buf);\n', ''),
 ("replace not paired",        'mutate.c', 'ins->paired = is_replace ? 1 : (chain_to_prev ? 1 : 0);', 'ins->paired = chain_to_prev ? 1 : 0;'),
]
def summary(log):
    t = open(log, errors='replace').read()
    return len(re.findall(r'^RESULT .*:OK', t, re.M)), re.findall(r'^(?:DIFF|PROP|HIST) \S+ \S+ step \d+ (?:field )?(\S+)', t, re.M)[:1]
if sys.argv[1] == '--c':
    root, work, emil, commit = sys.argv[2:6]
    print("| C bug seeded | Clean seeds of 20 | First failure |"); print("|---|---|---|")
    for i, (name, f, a, b) in enumerate(CBUGS):
        d = os.path.join(work, 'c%d' % i)
        os.makedirs(d)
        tree = os.path.join(d, 'r'); os.makedirs(tree)
        subprocess.run(f'git -C {emil} archive {commit} | tar -x -C {tree}', shell=True, check=True)
        p = os.path.join(tree, f); s = open(p).read(); assert a in s, name
        open(p, 'w').write(s.replace(a, b))
        subprocess.run(['git','init','-q',tree]); subprocess.run(['git','-C',tree,'add','-A'])
        subprocess.run(['git','-C',tree,'-c','user.email=x@example.invalid','-c','user.name=x','commit','-qm','seed'])
        subprocess.run([root+'/tests/undo/build.sh', tree, 'HEAD', d+'/b'], check=True, capture_output=True)
        log = d + '/log'
        subprocess.run([root+'/scripts/undo-diff.sh', d+'/b/driver', 'valid', '1', '20', '2000', d+'/w', log])
        ok, first = summary(log)
        print(f"| {name} | {ok} | {first[0] if first else 'NOT DETECTED'} |", flush=True)
else:
    root, work, drv = sys.argv[1:4]
    print("| Model bug seeded | Clean seeds of 20 | First failure |"); print("|---|---|---|")
    for i, (name, a, b) in enumerate(MODEL):
        d = os.path.join(work, 'm%d' % i)
        shutil.copytree(os.path.join(root,'acl2'), d+'/acl2', ignore=shutil.ignore_patterns('*.out','*.time','atc-*','c-link','trivial'))
        os.makedirs(d+'/scripts'); shutil.copy(os.path.join(root,'scripts/undo-diff.sh'), d+'/scripts/')
        for x in ('model.cert','model.fasl','model.port'):
            try: os.unlink(d+'/acl2/undo/'+x)
            except FileNotFoundError: pass
        p = d+'/acl2/undo/model.lisp'; s = open(p).read(); assert a in s, name
        open(p,'w').write(s.replace(a,b))
        log = d+'/log'
        subprocess.run([d+'/scripts/undo-diff.sh', drv, 'valid', '1', '20', '2000', d+'/w', log])
        ok, first = summary(log)
        print(f"| {name} | {ok} | {first[0] if first else 'NOT DETECTED'} |", flush=True)
