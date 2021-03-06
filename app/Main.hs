module Main where

import COC.COC
import COC.Parser
import Control.Monad (foldM)
import Control.Monad.Trans
import Control.Lens
import System.Environment
import System.Console.Haskeline

libFiles :: [String]
libFiles = ["./src/COC/lib/bool.coc",
            "./src/COC/lib/pair.coc",
            "./src/COC/lib/nat.coc",
            "./src/COC/lib/natmisc.coc",
            "./src/COC/lib/list.coc",
            "./src/COC/lib/listmisc.coc",
            "./src/COC/lib/maybe.coc",
            "./src/COC/lib/misc.coc",
            "./src/COC/lib/vector.coc"
           ]

loadFiles :: IO String
loadFiles = foldM (\content file -> do
                    fileContent <- readFile file
                    return $ content ++ fileContent)
                  "" libFiles

readAndCheck :: String -> IO (Maybe (Expr, Type))
readAndCheck line = do
  fileContents <- loadFiles
  let expr = parseExpr $ "let " ++ fileContents ++ " in " ++ line
  case typeCheck expr of
    Left msg -> do putStrLn $ "Type error: " ++ msg; return Nothing
    Right typ -> return $ Just (expr, typ)

evalPrint :: Bool -> String -> IO ()
evalPrint isSkip line = do
  mt <- readAndCheck line
  case mt of
    Nothing -> return ()
    Just (e, t) -> do
      let v = nf e
          (v', t') = if isSkip then skipLambda v t else (v, t)
      putStrLn $ show v' ++ " :: " ++ show t'
  return ()

loop :: Bool -> InputT IO ()
loop isSkip = do
  minput <- getInputLine "λ> "
  case minput of
    Nothing -> do
      outputStrLn "Goodbye."
      return ()
    Just input -> (liftIO $ evalPrint isSkip input) >> (loop isSkip);

main :: IO ()
main = do
  args <- getArgs
  case (args ^? element 0) of
    Just arg -> if arg == "skip"
               then runInputT defaultSettings (loop True)
               else runInputT defaultSettings (loop False)
    Nothing -> runInputT defaultSettings (loop False)
