module STLC.Syntax where

import STLC.Type
import STLC.Context
import Data.IORef
import Data.Maybe
import Control.Monad
import System.IO.Unsafe (unsafePerformIO)
import qualified Text.PrettyPrint as PP

data Term = TmTrue
          | TmFalse
          | TmVar Int Int -- the last value store the lambda abs count in global context
          | TmAbs Name Type Term
          | TmApp Term Term
          | TmZero
          | TmSucc Term
          | TmPred Term
          | TmIsZero Term
          -- let x:T1 = t1 in t2 could be desuger to (λ x:T1. t2) t1
          -- letrec x:T1 = t1 in t2 could be desuger to let x:T1 = fix (λx:T1. t1) in t2 then desuger to (λx:T1. t2) (fix (λx:T1. t1))
          | TmLet Name Term Term
          | TmIf Term Term Term
          | TmFix Term
          deriving (Show, Eq)

intVal :: Term -> Maybe Int
intVal TmZero = return 0
intVal (TmSucc n) = liftM2 (+) (return 1) (intVal n)
intVal (TmPred n) = liftM2 (+) (return (-1)) (intVal n)
intVal _  = Nothing

showTerm' :: Term -> Context -> String
showTerm' t ctx = case t of
                    TmTrue -> "true"
                    TmFalse -> "false"
                    TmVar n _ -> index2name n ctx
                    TmAbs x t body -> let (x', ctx') = pickFreshName x ctx in "(λ " ++ x' ++ ": " ++ show t ++ ". " ++ showTerm' body ctx' ++ ")"
                    TmApp fn arg -> "(" ++ showTerm' fn ctx ++ " " ++ showTerm' arg ctx ++ ")"
                    TmZero -> "0"
                    TmSucc t -> let n = intVal t in fromMaybe ("(succ " ++ showTerm' t ctx ++ ")") (liftM show n)
                    TmPred t -> let n = intVal t in fromMaybe ("(pred " ++ showTerm' t ctx ++ ")") (liftM show n)
                    TmIsZero t -> "(zero? " ++ showTerm' t ctx ++ ")"
                    TmLet x def body -> "(let" ++ show x ++ " = " ++ showTerm' def ctx ++ " in " ++ showTerm' body ((x, NameBind):ctx) ++ ")"
                    TmIf cond consequent alternative -> "(if " ++ showTerm' cond ctx ++ " then " ++ showTerm' consequent ctx ++ " else " ++ showTerm' alternative ctx ++ ")"
                    TmFix t -> "(fix " ++ showTerm' t ctx ++ ")"

showTerm :: Term -> PP.Doc
showTerm t = PP.text $ showTerm' t []

-- Shifting

walkTmMap :: (Int -> Int -> Int -> Term) -> Int -> Term -> Term
walkTmMap onvar c t = case t of
                        TmTrue -> t
                        TmFalse -> t
                        TmVar k n -> onvar c k n
                        TmAbs name ty body -> TmAbs name ty (walkTmMap onvar (c + 1) body)
                        TmApp fn arg -> TmApp (walkTmMap onvar c fn) (walkTmMap onvar c arg)
                        TmZero -> t
                        TmSucc t' -> TmSucc $ walkTmMap onvar c t'
                        TmPred t' -> TmPred $ walkTmMap onvar c t'
                        TmIsZero t' -> TmIsZero $ walkTmMap onvar c t'
                        TmIf cond consequent alternative -> TmIf (walkTmMap onvar c cond) (walkTmMap onvar c consequent) (walkTmMap onvar c alternative)
                        TmLet x def body -> TmLet x (walkTmMap onvar c def) (walkTmMap onvar (c+1) body)
                        TmFix t' -> TmFix $ walkTmMap onvar c t'

termShiftAbove :: Int -> Int -> Term -> Term
termShiftAbove d c t = walkTmMap (\c k n -> if k >= c then TmVar (k + d) (n + d) else TmVar k (n + d)) c t

termShift :: Int -> Term -> Term
termShift d t = termShiftAbove d 0 t

-- Substitution

termSubst :: Int -> Term -> Term -> Term
termSubst j s t = walkTmMap (\c k n -> if k == j + c then termShift c s else TmVar k n) 0 t

-- beta reduction
termSubstTop :: Term -> Term -> Term
termSubstTop s t = termShift (-1) (termSubst 0 (termShift 1 s) t)
