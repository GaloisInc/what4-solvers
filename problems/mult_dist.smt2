; Automatically created by SBV on 2021-09-16 10:36:56.252289 PDT
(set-option :produce-models true)
(set-logic QF_BV)
; --- uninterpreted sorts ---
; --- tuples ---
; --- sums ---
; --- literal constants ---
; --- skolem constants ---
(declare-fun s0 () (_ BitVec 4))
(declare-fun s1 () (_ BitVec 4))
(declare-fun s2 () (_ BitVec 4))
; --- constant tables ---
; --- skolemized tables ---
; --- arrays ---
; --- uninterpreted constants ---
; --- user given axioms ---
; --- preQuantifier assignments ---
(define-fun s3 () (_ BitVec 4) (bvadd s1 s2))
(define-fun s4 () (_ BitVec 4) (bvmul s0 s3))
(define-fun s5 () (_ BitVec 4) (bvmul s0 s1))
(define-fun s6 () (_ BitVec 4) (bvmul s0 s2))
(define-fun s7 () (_ BitVec 4) (bvadd s5 s6))
(define-fun s8 () Bool (= s4 s7))
; --- arrayDelayeds ---
; --- arraySetups ---
; --- formula ---
; --- postQuantifier assignments ---
; --- delayedEqualities ---
; -- finalAssert ---
(assert (not s8))
(check-sat)
